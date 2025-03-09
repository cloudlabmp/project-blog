---
title: "Customizing Your MkDocs Blog"
date: 2025-03-09
authors:
  - matthew
  - team
  - squidfunk
  - james
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

# Customizing Your MkDocs Blog 🎨

Once you've set up your MkDocs blog, it's time to personalize it. In this post, I'll cover various customizations, including **social media sharing hooks, changing the blog icon and favicon, adding authors, and using tags**. These modifications will make your blog more interactive and visually appealing.

All of the steps covered in this guide are available in the [MKDocs Documentation](https://squidfunk.github.io/mkdocs-material/getting-started/) or via the superb video tutorials created by [James Willett](https://youtu.be/pPEUhfTZswc?si=AjoyIaM5Ig7MZdgo)

## Adding Social Media Sharing Hooks 🔄

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

**How the Code Works:**

- The script identifies blog post pages using a regular expression (`posts/.*`)
- It gets the current page URL and title from MkDocs
- It adds formatted markdown buttons at the end of your content
- The buttons link to X (Twitter) and Facebook with pre-filled sharing information

### **Enable the Hook in `mkdocs.yml`**

Modify `mkdocs.yml` to include the hook:

```yaml
hooks:
  - hooks/socialmedia.py
```

This will append social media sharing buttons to your posts.

## Changing the Blog Icon and Favicon 🖼️

Updating your blog's favicon and site icon enhances branding.

### **Prepare the Icons**

Save your icons in `docs/images/` as:

- `favicon.ico` (16x16 or 32x32 pixels) - Used by browsers in tabs and bookmarks
- `logo.png` (recommended 512x512 pixels) - Displayed in your site header/navigation

### **Update `mkdocs.yml`**

```yaml
extra:
  logo: images/logo.png
  favicon: images/favicon.ico
```

Note: These paths are relative to your `docs/` directory, and both settings should be nested under the `extra:` key in your configuration file.

### **Restart the Server**

Run `mkdocs serve` to preview the changes.

## Adding Authors 👥

To attribute posts to different authors, create an `authors.yml` file.

### **Create `authors.yml`**

In the `docs/` directory of your project, create a file named `authors.yml`:

```yaml
matthew:
  name: "Matthew Pollock"
  email: "matthew@example.com"
  website: "https://matthewblog.com"

team:
  name: "Blog Team"
  website: "https://teamwebsite.com"

squidfunk:
  name: "SquidFunk"
  website: "https://squidfunk.github.io/"
```

### **Link Authors to Posts**

Modify each post's metadata:

```yaml
authors:
  - matthew
  - team
```

## Adding Tags 🏷️

Tags help categorize your blog posts.

### **Create `tags.md`**

Create a `docs/tags.md` file. Below are the tags used in this blog:

```yaml
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

## Enabling Comments on Blog Posts 💬

If you want to enable comments on blog posts, follow these steps:

### **Create the Comments Template**

Create a directory `overrides/partials/` if it doesn't exist, then add a file called `comments.html` with your Disqus integration code:

```html
<div id="disqus_thread"></div>
<script>
  var disqus_config = function () {
    this.page.url = window.location.href;
    this.page.identifier = document.title;
  };
  (function() {
    var d = document, s = d.createElement('script');
    s.src = 'https://your-disqus-name.disqus.com/embed.js';
    s.setAttribute('data-timestamp', +new Date());
    (d.head || d.body).appendChild(s);
  })();
</script>
```

**Note:** Replace `your-disqus-name` with your Disqus shortname, which you can find in your Disqus admin panel after creating a site.

### **Enable Comments in `mkdocs.yml`**

```yaml
extra:
  comments: true
```

Restart MkDocs and test:

```sh
mkdocs serve
```

## Theme Customization 🎭

The Material theme offers extensive customization options for colors, fonts, and more.

### **Custom Color Scheme**

Add this to your `mkdocs.yml`:

```yaml
theme:
  name: material
  palette:
    # Light mode
    - media: "(prefers-color-scheme: light)"
      scheme: default
      primary: indigo
      accent: indigo
      toggle:
        icon: material/toggle-switch-off-outline
        name: Switch to dark mode
    # Dark mode
    - media: "(prefers-color-scheme: dark)"
      scheme: slate
      primary: blue
      accent: blue
      toggle:
        icon: material/toggle-switch
        name: Switch to light mode
```

### **Custom Fonts**

```yaml
theme:
  font:
    text: Roboto
    code: Roboto Mono
```

## Analytics Integration 📊

Add analytics to track your blog's performance.

### **Google Analytics**

```yaml
extra:
  analytics:
    provider: google
    property: G-XXXXXXXXXX
```

### **Plausible Analytics**

```yaml
extra:
  analytics:
    provider: plausible
    domain: yourdomain.com
```

## SEO Optimization 🔍

Improve your blog's search engine visibility.

### **Add Meta Tags**

```yaml
plugins:
  - meta
```

Then in each post, add:

```yaml
meta:
  description: "A detailed guide to customizing MkDocs blogs"
  keywords: mkdocs, blog, customization, web development
  robots: index, follow
  og:image: /assets/social-card.png
```

## Performance Optimization ⚡

Keep your blog fast and responsive.

### **Image Optimization**

1. Compress all images before adding them to your blog
2. Use modern formats like WebP
3. Specify image dimensions in HTML to prevent layout shifts

### **Lazy Loading**

Enable lazy loading of images using the `loading="lazy"` attribute:

```markdown
![Alt text](image.jpg){ loading=lazy }
```

## Understanding Your MkDocs Project Structure 📁

Once you have created an MkDocs project and added the components listed in the two posts in this series, you'll see a folder structure similar to this:

```
project-blog/
├── docs/                 # Documentation files (Markdown content)
│   ├── index.md          # Homepage of your site
│   ├── tags.md           # Tags page for blog posts
│   ├── authors.yml       # Defines author metadata
│   ├── posts/            # Blog post storage
│   │   ├── firstpost.md  
│   │   ├── secondpost.md  
│   │   ├── thirdpost.md  
│   ├── images/           # Store all your images here
│   │   ├── logo.png  
│   │   ├── favicon.ico
├── hooks/                # Custom MkDocs hooks (like social media sharing)
├── overrides/            # Custom HTML overrides for Material theme
│   ├── partials/comments.html  # Comment system (if enabled)
├── mkdocs.yml            # Configuration file for MkDocs
├── requirements.txt      # Python dependencies
├── .gitignore            # Files to exclude from Git
```

This structure keeps content organized, making it easy to scale your documentation or blog.

## Deploying Updates 🚀

Whenever you make changes, redeploy your site:

```sh
mkdocs gh-deploy
```

This command builds your site and pushes it to the `gh-pages` branch of your repository.

## Troubleshooting Tips 🔧

### **Social Media Buttons Not Showing**

- Ensure your `mkdocs.yml` has the `site_url` property set correctly
- Verify the hook is correctly installed in the `hooks/` directory

### **Favicon Not Displaying**

- Clear your browser cache
- Ensure the path in `mkdocs.yml` is correct relative to the `docs/` directory

### **Comments Not Loading**

- Check your browser console for JavaScript errors
- Verify your Disqus shortname is correct
- Ensure `extra.comments` is set to `true` in `mkdocs.yml`

### **Deployment Issues**

If `mkdocs gh-deploy` fails:

```sh
# Ensure you have the latest version of MkDocs
pip install --upgrade mkdocs mkdocs-material

# Check your git configuration
git config --global user.name "Your Name"
git config --global user.email "your.email@example.com"
```

## Conclusion 🎉

With these customizations, your MkDocs blog will be more interactive and visually engaging. The additions of social sharing, comments, better visualization with icons, and proper author attribution will make your blog more professional and user-friendly.

In our next post, we'll cover advanced MkDocs features including content reuse, advanced search configuration, and integration with other tools in your workflow.

Stay tuned for more tips!

---

📌 *Published on:* `2025-03-09`  
⏳ *Read time:* 8 min
