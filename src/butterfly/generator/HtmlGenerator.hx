package butterfly.generator;

using StringTools;
using DateTools;
import butterfly.core.Post;
import ButterflyConfig;
import butterfly.html.TagFinder;
import butterfly.html.HtmlTag;

class HtmlGenerator {

  private var layoutHtml:String;
  private static inline var TITLE_PLACEHOLDER:String = '<butterfly-title />';
  private static inline var CONTENT_PLACEHOLDER:String = '<butterfly-content />';
  private static inline var PAGES_LINKS_PLACEHOLDER:String = '<butterfly-pages />';
  private static inline var TAGS_PLACEHOLDER:String = '<butterfly-tags />';
  private static inline var TAGS_COUNTS_OPTION:String = 'show-counts';
  private static inline var COMMENTS_PLACEHOLDER:String = '<butterfly-comments />';
  private static inline var DISQUS_HTML_FILE:String = 'templates/disqus.html';
  private static inline var DISQUS_PAGE_URL:String = 'PAGE_URL';
  private static inline var DISQUS_PAGE_IDENTIFIER = 'PAGE_IDENTIFIER';

  private var allContent:Array<Post>;

  public function new(layoutHtml:String, posts:Array<Post>, pages:Array<Post>)
  {
    this.layoutHtml = layoutHtml;
    if (this.layoutHtml.indexOf(CONTENT_PLACEHOLDER) == -1) {
      throw "Layout HTML doesn't have the blog post placeholder in it: " + CONTENT_PLACEHOLDER;
    }

    // Pages first so if both a post and page share a title, the page wins.
    this.allContent = pages.concat(posts);

    var pagesTag:HtmlTag = TagFinder.findTag(PAGES_LINKS_PLACEHOLDER, this.layoutHtml);
    var pagesHtml:String = this.generatePagesLinksHtml(pagesTag, pages);
    this.layoutHtml = this.layoutHtml.replace(pagesTag.html, pagesHtml);

    var tagsHtml = this.generateTagsHtml();
    // Replace it. The tag may have options.
    var butterflyTag:HtmlTag = TagFinder.findTag(TAGS_PLACEHOLDER, this.layoutHtml);
    if (butterflyTag != null)
    {
      this.layoutHtml = this.layoutHtml.replace(butterflyTag.html, tagsHtml);
    }
  }

  /**
  Generates the HTML for a post, using values from config (like the site URL).
  Returns the fully-formed, final HTML (after rendering to Markdown, adding
  the HTML with the post's tags, etc.).
  */
  public function generatePostHtml(post:Post, config:ButterflyConfig) : String
  {
    // substitute in content
    var tagsHtml = "";
    if (post.tags.length > 0) {
      tagsHtml = "<p><strong>Tagged with:</strong> ";
      for (tag in post.tags) {
        tagsHtml += '<a href="${tagLink(tag)}">${tag}</a>, ';
      }
      tagsHtml = tagsHtml.substr(0, tagsHtml.length - 2) + "</p>"; // trim final ", "
    }

    // posted-on date
    var postedOnHtml = "";
    if (post.createdOn != null) {
      postedOnHtml = '<p class="blog-post-meta">Posted ${post.createdOn.format("%Y-%m-%d")}</p>';
    }

    var finalContent = generateIntraSiteLinks(post.content);
    var finalHtml = '${tagsHtml}\n${postedOnHtml}\n${finalContent}\n';
    var toReturn = this.layoutHtml.replace(CONTENT_PLACEHOLDER, finalHtml);

    // replace <butterfly-title /> with the title, if it exists
    toReturn = toReturn.replace(TITLE_PLACEHOLDER, post.title);

    // comments (disqus snippet)
    var disqusHtml = getDisqusHtml(post, config);
    toReturn = toReturn.replace(COMMENTS_PLACEHOLDER, disqusHtml);

    // prefix the post name to the title tag
    toReturn = toReturn.replace("<title>", '<title>${post.title} | ');
    return toReturn;
  }

  public function generateIntraSiteLinks(content:String) : String
  {
    var toReturn = content;
    // Don't bother scanning if there are no links (syntax: [[title]])
    if (toReturn.indexOf("[[") > -1) {
      for (c in allContent) {
        var titlePlaceholder = new EReg('\\[\\[${c.title}]]', "i");
        if (titlePlaceholder.match(toReturn)) {
          var titleLink = '<a href="${c.url}.html">${c.title}</a>';
          toReturn = titlePlaceholder.replace(toReturn, titleLink);
        }
      }
    }

    return toReturn;
  }

  // Precondition: posts are sorted in the order we want to list them.
  public function generateTagPageHtml(tag:String, posts:Array<Post>):String
  {
    var count = 0;
    var html = "<ul>";
    for (post in posts) {
      if (post.tags.indexOf(tag) > -1) {
        html += '<li><a href="${post.url}.html">${post.title}</a></li>';
        count++;
      }
    }
    html += "</ul>";
    html = '<p>${count} posts tagged with ${tag}:</p>\n${html}';
    return this.layoutHtml.replace(CONTENT_PLACEHOLDER, html);
  }

  public function generateHomePage(posts:Array<Post>) : String
  {
    var html = "<ul>";
    for (post in posts) {
      html += '<li><a href="${post.url}.html">${post.title}</a> (${post.createdOn.format("%Y-%m-%d")})</li>';
    }
    html += "</ul>";
    return this.layoutHtml.replace(CONTENT_PLACEHOLDER, html);
  }

  private function generatePagesLinksHtml(pagesTag:HtmlTag, pages:Array<Post>) : String
  {
    var linkAttributes:String = pagesTag.attribute("link-attributes");
    var linkPrefix:String = pagesTag.attribute("link-prefix");
    var linkSuffix:String = pagesTag.attribute("link-suffix");

    var html = "";

    for (page in pages) {
     html += '${linkPrefix}<a ${linkAttributes} href="${page.url}.html">${page.title}</a>${linkSuffix}';
    }

    return html;
  }

  private function generateTagsHtml() : String
  {
    var butterflyTag:HtmlTag = TagFinder.findTag(TAGS_PLACEHOLDER, this.layoutHtml);
    if (butterflyTag != null) {
      var tagCounts:Map<String, Int> = new Map<String, Int>();

      // Calculate tag counts. We need the list of tags even if we don't show counts.
      for (post in this.allContent) {
        for (tag in post.tags) {
          if (!tagCounts.exists(tag)) {
            tagCounts.set(tag, 0);
          }
          tagCounts.set(tag, tagCounts.get(tag) + 1);
        }
      }

      var tags = sortKeys(tagCounts);
      var html = "<ul>";
      for (tag in tags) {
        html += '<li><a href="${tagLink(tag)}">${tag}</a>';
        if (butterflyTag.attribute(TAGS_COUNTS_OPTION) != "") {
          html += ' (${tagCounts.get(tag)})';
        }
        html += '</li>\n';
      }
      html += "</ul>";
      return html;
    } else {
      // Laytout doesn't include tags HTML.
      return "";
    }
  }

  private function getDisqusHtml(post:Post, config:ButterflyConfig):String
  {
    var template = sys.io.File.getContent(DISQUS_HTML_FILE);
    var url = '${config.siteUrl}/${post.url}';
    template = template.replace(DISQUS_PAGE_URL, '"${url}"');
    template = template.replace(DISQUS_PAGE_IDENTIFIER, '"${post.id}"');
    return template;
  }

  private function tagLink(tag:String):String
  {
    return 'tag-${tag}.html';
  }

  private function sortKeys(map:haxe.ds.StringMap<Dynamic>) : Array<String>
  {
    // Sort tags by name. Collect them into an array, sort that, et viola.
    var keys = new Array<String>();

    var mapKeys = map.keys();
    while (mapKeys.hasNext()) {
      var next = mapKeys.next();
      if (keys.indexOf(next) == -1) {
        keys.push(next);
      }
    }

    keys.sort(function(a:String, b:String):Int {
      a = a.toUpperCase();
      b = b.toUpperCase();

      if (a < b) {
        return -1;
      }
      else if (a > b) {
        return 1;
      } else {
        return 0;
      }
    });

    return keys;
  }
}
