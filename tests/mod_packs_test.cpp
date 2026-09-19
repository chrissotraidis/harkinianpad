#include "ModCatalog.h"
#include "ModPackImport.h"
#include <zip.h>
#ifdef INCLUDE_MPQ_SUPPORT
#include <StormLib.h>
#endif
#include <cassert>
#include <fstream>
#include <iostream>
#include <functional>
namespace fs = std::filesystem;
static void Zip(const fs::path& path, const std::vector<std::pair<std::string, std::string>>& entries) {
    auto* zip = zip_open(path.c_str(), ZIP_CREATE | ZIP_TRUNCATE, nullptr);
    assert(zip);
    for (const auto& [name, data] : entries) {
        auto* source = zip_source_buffer(zip, data.data(), data.size(), 0);
        assert(source && zip_file_add(zip, name.c_str(), source, 0) >= 0);
    }
    assert(zip_close(zip) == 0);
}
static std::string Read(const fs::path& path) {
    std::ifstream file(path, std::ios::binary);
    return {std::istreambuf_iterator<char>(file), {}};
}
static void Reject(const std::function<void()>& action) {
    bool rejected = false;
    try { action(); } catch (const std::exception&) { rejected = true; }
    assert(rejected);
}
int main(int argc, char** argv) {
    assert(argc == 2 || argc == 4);
    const fs::path root(argv[1]);
    if (argc == 4) {
        std::cout << "Imported real pack count=" << ModPackImport::Import(argv[2], argv[3]) << '\n';
        return 0;
    }
    std::map<std::string, fs::path> catalog{{"a/same.o2r", "a/same.o2r"}, {"b/same.o2r", "b/same.o2r"},
                                         {"high.o2r", "high.o2r"}, {"with|pipe.o2r", "with|pipe.o2r"}};
    auto legacy = ModCatalog::Reconcile(catalog, {{"same", "same", "high"}, {}}, true);
    assert((legacy.enabled == std::vector<std::string>{"a/same.o2r", "high.o2r", "with|pipe.o2r"}));
    assert((legacy.disabled == std::vector<std::string>{"b/same.o2r"}));
    auto current = ModCatalog::Reconcile(catalog, {{"b/same.o2r", "a/same.o2r", "missing.o2r"}, {}}, false);
    assert((current.enabled == std::vector<std::string>{"b/same.o2r", "a/same.o2r"}));
    assert(current.disabled.size() == 2);
    assert(ModCatalog::Reconcile(catalog, {}, false).enabled.empty()); // disable-all survives restart
    assert(ModCatalog::Reconcile(catalog, {}, true).enabled.size() == 4); // old fresh installation
    // Forward loading with last-wins retains the top (reverse-drawn) pack's priority.
    std::string winner;
    for (const auto& id : current.enabled) winner = id;
    assert(winner == current.enabled.back());
    const auto good = root / "good.o2r";
    Zip(good, {{"alt/test", "synthetic asset"}});
    assert(ModPackImport::Import(good, root / "direct") == 1);
    assert(Read(good) == Read(root / "direct/good.o2r"));
    Reject([&] { ModPackImport::Import(good, root / "direct"); });
    assert(Read(good) == Read(root / "direct/good.o2r")); // never remove preexisting destination
    const auto bundle = root / "bundle.zip";
    Zip(bundle, {{"one/same.o2r", Read(good)}, {"two/same.o2r", Read(good)}, {"README.txt", "ignored"}});
    assert(ModPackImport::Import(bundle, root / "bundle") == 2);
    assert(!fs::exists(root / "bundle/README.txt"));
    Zip(bundle, {{"../outside.o2r", Read(good)}});
    Reject([&] { ModPackImport::Import(bundle, root / "traversal"); });
    assert(!fs::exists(root / "traversal") && !fs::exists(root / "outside.o2r"));
    Zip(bundle, {{"/absolute.o2r", Read(good)}});
    Reject([&] { ModPackImport::Import(bundle, root / "absolute"); });
    Zip(bundle, {{"..\\outside.o2r", Read(good)}});
    Reject([&] { ModPackImport::Import(bundle, root / "windows"); });
    Zip(bundle, {{"good.o2r", Read(good)}, {"bad.o2r", "broken"}});
    Reject([&] { ModPackImport::Import(bundle, root / "partial"); });
    assert(!fs::exists(root / "partial")); // whole bundle rollback
    std::ofstream(root / "bad.o2r") << "not an archive";
    Reject([&] { ModPackImport::Import(root / "bad.o2r", root / "invalid"); });
    std::ofstream(root / "bad.7z") << "unsupported";
    Reject([&] { ModPackImport::Import(root / "bad.7z", root / "sevenzip"); });
    assert(!fs::exists(root / "sevenzip"));
#ifdef INCLUDE_MPQ_SUPPORT
    HANDLE archive = nullptr, file = nullptr;
    const auto otr = root / "synthetic.otr";
    assert(SFileCreateArchive(otr.c_str(), MPQ_CREATE_ARCHIVE_V2 | MPQ_CREATE_LISTFILE, 32, &archive));
    assert(SFileCreateFile(archive, "alt/test", 0, 4, 0, 0, &file));
    assert(SFileWriteFile(file, "test", 4, 0));
    assert(SFileFinishFile(file));
    assert(SFileCloseArchive(archive));
    assert(ModPackImport::Import(otr, root / "otr") == 1);
    assert(Read(otr) == Read(root / "otr/synthetic.otr"));
    const auto noList = root / "no-list.otr";
    SFILE_CREATE_MPQ create = {};
    create.cbSize = sizeof(create);
    create.dwMpqVersion = MPQ_FORMAT_VERSION_2;
    create.dwSectorSize = 4096;
    create.dwMaxFileCount = 32;
    assert(SFileCreateArchive2(noList.c_str(), &create, &archive));
    assert(SFileCreateFile(archive, "alt/test", 0, 4, 0, 0, &file));
    assert(SFileWriteFile(file, "test", 4, 0));
    assert(SFileFinishFile(file));
    assert(SFileCloseArchive(archive));
    Reject([&] { ModPackImport::Import(noList, root / "no-list"); });
    assert(!fs::exists(root / "no-list"));
    std::ofstream(root / "bad.otr") << "broken";
    Reject([&] { ModPackImport::Import(root / "bad.otr", root / "invalid-otr"); });
    std::cout << "OTR validation and import passed\n";
#endif
    std::ofstream(root / "oversized.o2r") << "";
    fs::resize_file(root / "oversized.o2r", 16ULL * 1024 * 1024 * 1024 + 1);
    Reject([&] { ModPackImport::Import(root / "oversized.o2r", root / "oversized"); });
    assert(!fs::exists(root / "oversized"));
    std::cout << "Mod catalog migration, selection, identity, import and rollback checks passed\n";
}
