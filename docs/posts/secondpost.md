---
title: "Setting Up MkDocs for Your Blog"
draft: true
date:
  created: 2025-03-05
  updated: 2025-03-05
authors:
  - matthew
  - team
  - squidfunk
description: "A step-by-step guide to setting up MkDocs for blogging."
categories:
  - MkDocs
  - Documentation
  - Blogging
  - Tech
tags:
  - technology
  - learning
---

# Setting Up MkDocs for Your Blog

If you're looking for a simple yet powerful way to create and manage your documentation or blog, **MkDocs** is a fantastic option. In this post, I'll walk you through the steps to set up MkDocs for your blog and get it hosted on GitHub Pages.

## Prerequisites

Before we begin, ensure you have the following installed:

- **Python 3.x** – MkDocs is a Python-based tool.
- **pip** – Python's package manager.
- **Git** – To manage version control and push changes to GitHub.

## Step 1: Install MkDocs

First, install MkDocs using `pip`:

```sh
pip install mkdocs
```

To verify the installation, run:

```sh
mkdocs --version
```

## Step 2: Create a New MkDocs Project

Navigate to the directory where you want to create your blog and run:

```sh
mkdocs new my-blog
cd my-blog
```

This creates a basic MkDocs project structure.

## Step 3: Customize `mkdocs.yml`

The `mkdocs.yml` file is the configuration file for your blog. Open it in a text editor and modify the site name:

```yaml
site_name: My Tech Blog
site_description: A blog documenting my projects and insights
repo_url: https://github.com/yourusername/my-blog
```

You can also add a theme (e.g., `material`):

```sh
pip install mkdocs-material
```

Then update `mkdocs.yml`:

```yaml
theme:
  name: material
```

## Step 4: Run MkDocs Locally

To preview your blog locally, run:

```sh
mkdocs serve
```

Then open `http://127.0.0.1:8000/` in your browser to see your blog in action!

## Step 5: Deploy to GitHub Pages

1. Initialize a Git repository and commit your changes:

   ```sh
   git init
   git add .
   git commit -m "Initial commit"
   ```

2. Create a new GitHub repository and link it:

   ```sh
   git remote add origin https://github.com/yourusername/my-blog.git
   git branch -M main
   git push -u origin main
   ```

3. Deploy your blog to GitHub Pages:

   ```sh
   mkdocs gh-deploy
   ```

Your blog is now live! 🎉

## Conclusion

Setting up MkDocs is straightforward, and with GitHub Pages, you can host your blog for free. In future posts, I'll cover more customizations, themes, and plugins to enhance your MkDocs blog.

---

📌 *Published on:* `2025-03-04
