package butterfly.core;

import sys.io.File;
import sys.FileSystem;
import butterfly.core.Post;
import test.helpers.ContentMaker;
import massive.munit.Assert;

class PageTest
{
  private static inline var TEST_FILES_DIR = "test/temp/page";

  @Before
  public function createTestFilesDirectory() {
    FileSystem.createDirectory(TEST_FILES_DIR);
  }

  @After
  public function deleteTestFiles() {
    butterfly.io.FileSystem.deleteDirRecursively(TEST_FILES_DIR);
    FileSystem.deleteDirectory(TEST_FILES_DIR);
  }

  @Test
  public function defaultPageOrderIsZero()
  {
    var page = new Page();
    Assert.areEqual(0, page.order);
  }

  @Test
  public function parseParsesAllMetaDataProperly()
  {
    // Random sample of some orders we might use
    for (expected in [-10, -1, 0, 1, 3, 7]) {
      var page:Page = ContentMaker.createPage('meta-order: ${expected}\r\nHello, world!', '${TEST_FILES_DIR}/post-order.md');
      Assert.areEqual(expected, page.order);
    }
  }
}
