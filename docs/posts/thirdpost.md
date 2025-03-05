---
title: "Customizing Your MkDocs Blog"
date:
  created: 2024-06-06
  updated: 2025-03-05
readtime: 5
authors:
  - matthew
  - team
  - squidfunk
description: "Enhance your MkDocs blog with themes, plugins, and customization options."
categories:
  - MkDocs
  - Customization
  - Blogging
  - Tech
tags:
  - technology
  - learning
---

# Customizing Your MkDocs Blog

Once you've set up your MkDocs blog, it's time to personalize it. In this post, I'll cover various customizations, including **social media sharing hooks, changing the blog icon and favicon, adding authors, and using tags**. These modifications will make your blog more interactive and visually appealing.

## Adding Social Media Sharing Hooks

To allow users to share your blog posts easily, you can create a `socialmedia.py` hook. This script appends sharing buttons to each post.

### **Create the Hook File**

Inside your project, create a folder named `hooks/` if it doesn't already exist, and then add a file called `socialmedia.py`:

```sh
mkdir hooks
nano hooks/socialmedia.py
```

### **Add the Social Media Sharing Code**

Paste the following into `socialmedia.py`:

```python
from textwrap import dedent
import urllib.parse
import re

x_intent = "https://x.com/intent/tweet"
fb_sharer = "https://www.facebook.com/sharer/sharer.php"
include = re.compile(r"posts/.*")

def on_page_markdown(markdown, **kwargs):
    page = kwargs['page']
    config = kwargs['config']
    if not include.match(page.url):
        return markdown

    page_url = config.site_url + page.url
    page_title = urllib.parse.quote(page.title + '\n')

    return markdown + dedent(f"""
    [Share on :simple-x:]({x_intent}?text={page_title}&url={page_url}){{ .md-button }}
    [Share on :simple-facebook:]({fb_sharer}?u={page_url}){{ .md-button }}
    """)
```

### **Enable the Hook in `mkdocs.yml`**

Modify `mkdocs.yml` to include the hook:

```yaml
hooks:
  - hooks/socialmedia.py
```

This will append social media sharing buttons to your posts.

## Changing the Blog Icon and Favicon

Updating your blog’s favicon and site icon enhances branding.

### **Prepare the Icons**

Save your icons in `docs/images/` as:

- `favicon.ico` (16x16 or 32x32 pixels)
- `logo.png` (recommended 512x512 pixels)

### **Update `mkdocs.yml`**

```yaml
extra:
  logo: images/logo.png
  favicon: images/favicon.ico
```

### **Restart the Server**

Run `mkdocs serve` to preview the changes.

## Adding Authors

To attribute posts to different authors, create an `authors.yml` file.

### **Create `authors.yml`**

In the root of your project, create a file named `authors.yml`:

```yaml
matthew:
  name: "Matthew Pollock"
  email: "matthew@example.com"
  website: "https://matthewblog.com"

tteam:
  name: "Blog Team"
  website: "https://teamwebsite.com"

squidfunk:
  name: "SquidFunk"
  website: "https://squidfunk.github.io/"
```

### **Link Authors to Posts**

Modify each post’s metadata:

```yaml
authors:
  - matthew
  - team
```

## Adding Tags

Tags help categorize your blog posts.

### **Create `tags.md`**

Create a `docs/tags.md` file. Below are the tags used in this blog:

```yml
# Tags
tags:
  - technology
  - learning
```

### **Enable Tags in `mkdocs.yml`**

Modify `mkdocs.yml`:

```yaml
plugins:
  - tags:
      tags_file: tags.md
```

Now, you can tag posts like this:

```yaml
tags:
  - technology
  - learning
```

## Deploying Updates

Whenever you make changes, redeploy your site:

```sh
mkdocs gh-deploy
```

## Conclusion

With these customizations, your MkDocs blog will be more interactive and visually engaging. Stay tuned for more tips!

---

📌 *Published on:* `2024-06-06`
🔄 *Updated on:* `2025-03-05`
⏳ *Read time:* 5 min
