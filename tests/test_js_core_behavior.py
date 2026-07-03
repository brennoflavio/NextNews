import json
import pathlib
import re
import subprocess
import tempfile
import textwrap
import unittest


ROOT = pathlib.Path(__file__).resolve().parents[1]


class NewsApiCoreBehaviorTests(unittest.TestCase):
    def run_js(self, script):
        core = (ROOT / "qml/backend/NewsApiCore.js").read_text(encoding="utf-8")
        core = core.replace(".pragma library", "")
        with tempfile.NamedTemporaryFile("w", suffix=".js", delete=False, encoding="utf-8") as handle:
            handle.write(core)
            handle.write("\n")
            handle.write(script)
            path = handle.name
        try:
            result = subprocess.run(["node", path], check=True, text=True, capture_output=True)
            return json.loads(result.stdout)
        finally:
            pathlib.Path(path).unlink(missing_ok=True)

    def test_builds_urls_and_payloads(self):
        result = self.run_js(textwrap.dedent("""
            var starItem = { feedId: 7, guidHash: "abc" };
            console.log(JSON.stringify({
                base: apiBaseUrl("cloud.example.test/"),
                folders: foldersUrl("https://cloud.example.test"),
                items: itemsUrl("https://cloud.example.test", 0, 7, true),
                read: markReadUrl("https://cloud.example.test", true),
                unread: markReadUrl("https://cloud.example.test", false),
                star: starUrl("https://cloud.example.test", true),
                ids: idsPayload([1, "2"]),
                starPayload: starPayload([starItem])
            }));
        """))

        self.assertEqual(result["base"], "https://cloud.example.test/index.php/apps/news/api/v1-2")
        self.assertTrue(result["folders"].endswith("/folders"))
        self.assertIn("type=0", result["items"])
        self.assertIn("id=7", result["items"])
        self.assertTrue(result["read"].endswith("/items/read/multiple"))
        self.assertTrue(result["unread"].endswith("/items/unread/multiple"))
        self.assertTrue(result["star"].endswith("/items/star/multiple"))
        self.assertEqual(result["ids"], {"items": [1, 2]})
        self.assertEqual(result["starPayload"], {"items": [{"feedId": 7, "guidHash": "abc"}]})

    def test_parses_news_wrappers(self):
        result = self.run_js(textwrap.dedent(r"""
            var folders = parseFolders(JSON.stringify({ folders: [{ id: 1, name: "Tech" }] }));
            var createdFolders = parseFolders(JSON.stringify([{ id: 4, name: "Created" }]));
            var feeds = parseFeeds(JSON.stringify({ feeds: [{ id: 2, folderId: 1, title: "Feed", url: "https://example.test", unreadCount: 3 }] }));
            var items = parseItems(JSON.stringify({ items: [{ id: 9, feedId: 2, guidHash: "h", title: "Title", body: "<p>CNN Iran&#039;s &quot;test&quot;&nbsp;world</p>", pubDate: 10, unread: true, starred: false }] }));
            console.log(JSON.stringify({
                foldersOk: folders.ok,
                folderName: folders.folders[0].name,
                createdFoldersOk: createdFolders.ok,
                createdFolderName: createdFolders.folders[0].name,
                feedTitle: feeds.feeds[0].title,
                itemTitle: items.items[0].title,
                itemPreview: stripHtml(items.items[0].body),
                itemUnread: items.items[0].unread
            }));
        """))

        self.assertTrue(result["foldersOk"])
        self.assertEqual(result["folderName"], "Tech")
        self.assertTrue(result["createdFoldersOk"])
        self.assertEqual(result["createdFolderName"], "Created")
        self.assertEqual(result["feedTitle"], "Feed")
        self.assertEqual(result["itemTitle"], "Title")
        self.assertEqual(result["itemPreview"], "CNN Iran's \"test\" world")
        self.assertTrue(result["itemUnread"])


if __name__ == "__main__":
    unittest.main(verbosity=2)
