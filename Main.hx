using StringTools;
using DateTools;
using butterfly.Post;

class Main {
  static public function main() : Void {
    new Main().run();
  }

  public function new() { }

  public function run() : Void {
    if (Sys.args().length != 1) {
      throw "Usage: neko Main.n <source directory>";
    }

    var projectDir = Sys.args()[0];
    trace("Using " + projectDir + " as project directory");
    ensureDirExists(projectDir);

    var binDir = projectDir + "/bin";
    if (sys.FileSystem.exists(binDir)) {
      // always clean/rebuild
      deleteDirRecursively(binDir);
      sys.FileSystem.createDirectory(binDir);
    }

    var srcDir = projectDir + "/src";
    ensureDirExists(srcDir);

    var configFile = '${srcDir}/config.json';
    if (!sys.FileSystem.exists(configFile)) {
      throw 'Config file ${configFile} is missing. Please add it as a JSON file with fields for siteName, siteUrl, authorName, and authorEmail.';
    }
    var config:Dynamic = haxe.Json.parse(sys.io.File.getContent(configFile));

    copyDirRecursively(srcDir + '/content', binDir + '/content');

    var layoutFile = srcDir + "/layout.html";
    var homeFile = srcDir + "/" + config.homepageTemplate;

    // generate pages and tags first, because they appear in the header/layout
    var pages:Array<butterfly.Post> = getPostsOrPages(srcDir + '/pages', true);

    ensureDirExists(srcDir + '/posts' , true);
    var posts:Array<butterfly.Post> = getPostsOrPages(srcDir + '/posts');
    // sort by date, newest-first. Sorting by getTime() doesn't seem to work,
    // for some reason; sorting by the stringified dates (yyyy-mm-dd format) does.
    haxe.ds.ArraySort.sort(posts, function(a, b) {
      var x = a.createdOn.format("%Y-%m-%d");
      var y = b.createdOn.format("%Y-%m-%d");

      if (x < y ) { return 1; }
      else if (x > y) { return -1; }
      else { return 0; };

      //return result;
    });

    var tags = new Array<String>();

    // Calculate tag counts
    for (post in posts) {
      for (tag in post.tags) {
        if (tags.indexOf(tag) == -1) {
          tags.push(tag);
        }
      }
    }

    var layoutHtml = new butterfly.LayoutModifier(layoutFile, config).getHtml();
    var generator = new butterfly.HtmlGenerator(layoutHtml, posts, pages, config);
    var writer = new butterfly.FileWriter(binDir);

    for (post in posts) {
      var html = generator.generatePostHtml(post);
      writer.writePost(post, html);
    }

    for (page in pages) {
      var html = generator.generatePostHtml(page);
      writer.writePost(page, html);
    }

    for (tag in tags) {
      var html = generator.generateTagPageHtml(tag, posts);
      writer.write('tag-${tag}.html', html);
    }

    // [mck] it's possible to use an other template for the homepage
    if(config.homepageTemplate != null || config.homepageTemplate != ""){
      var layoutHtml2 = new butterfly.LayoutModifier(homeFile, config).getHtml();
      var generator2 = new butterfly.HtmlGenerator(layoutHtml2, posts, pages, config);
      var indexPage2 = generator2.generateHomePage(posts);
      writer.write("index.html", indexPage2);
    } else {
      var indexPage = generator.generateHomePage(posts);
      writer.write("index.html", indexPage);
    }

    var atomXml = butterfly.AtomGenerator.generate(posts, config);
    writer.write("atom.xml", atomXml);

    trace("Generated index page, " + posts.length + " posts and " + pages.length + " pages.");
  }

  private function ensureDirExists(path:String, ?isNeeded:Bool = false) : Void
  {
    if (!sys.FileSystem.exists(path)) {
      if(isNeeded){
        sys.FileSystem.createDirectory(path);
        throw path + " didn't exist, now it does, try building again!";
      } else {
        throw path + " doesn't exist.";
      }
    } else if (!sys.FileSystem.isDirectory(path)) {
      throw path + " isn't a directory";
    }
  }

  private function copyDirRecursively(srcPath:String, destPath:String) : Void
  {
    if (!sys.FileSystem.exists(destPath)) {
      sys.FileSystem.createDirectory(destPath);
    }

    if (sys.FileSystem.exists(srcPath) && sys.FileSystem.isDirectory(srcPath))
    {
      var entries = sys.FileSystem.readDirectory(srcPath);
      for (entry in entries) {
        if (sys.FileSystem.isDirectory(srcPath + '/' + entry)) {
          sys.FileSystem.createDirectory(srcPath + '/' + entry);
          copyDirRecursively(srcPath + '/' + entry, destPath + '/' + entry);
        } else {
          sys.io.File.copy(srcPath + '/' + entry, destPath + '/' + entry);
        }
      }
    } else {
      throw srcPath + " doesn't exist or isn't a directory";
    }
  }

  private function deleteDirRecursively(path:String) : Void
  {
    if (sys.FileSystem.exists(path) && sys.FileSystem.isDirectory(path))
    {
      var entries = sys.FileSystem.readDirectory(path);
      for (entry in entries) {
        if (sys.FileSystem.isDirectory(path + '/' + entry)) {
          deleteDirRecursively(path + '/' + entry);
          sys.FileSystem.deleteDirectory(path + '/' + entry);
        } else {
          sys.FileSystem.deleteFile(path + '/' + entry);
        }
      }
    }
  }

  private function getPostsOrPages(path:String, ?isPage:Bool = false) : Array<butterfly.Post>
  {
    if (sys.FileSystem.exists(path) && sys.FileSystem.isDirectory(path)) {
      var filesAndDirs = sys.FileSystem.readDirectory(path);
      var posts = new Array<butterfly.Post>();
      for (entry in filesAndDirs) {
        var relativePath = path + "/" + entry;
        if(entry.indexOf(".DS") != -1) continue;
        if (!sys.FileSystem.isDirectory(relativePath)) {
          posts.push(butterfly.Post.parse(relativePath, isPage));
        }
      }
      return posts;
    }
    return new Array<butterfly.Post>();
  }
}

typedef ButterflyConfig =  
{
  var siteName : String;
  var siteUrl : String;
  var authorName : String;
  ?optional var authorEmail : String;
  @optional var googleAnalyticsId : String;
  @optional var diskus : String;
  @optional var homepageTemplate : String;
}
