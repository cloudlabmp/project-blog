---
title: "Setting Up MkDocs for Your Blog"
date:
  created: 2025-02-15
  updated: 2025-02-15
authors:
  - matthew
  - james
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

# Setting Up MkDocs for Your Blog 📝

If you're looking for a simple yet powerful way to create and manage your documentation or blog, **MkDocs** is a fantastic option. MkDocs is a fast, static site generator that's geared towards building project documentation but works wonderfully for blogs too! In this post, I'll walk you through the steps to set up MkDocs with the popular Material theme and get it hosted on GitHub Pages.

All of the steps covered in this guide are available in the [MkDocs Documentation](https://squidfunk.github.io/mkdocs-material/getting-started/) or via the superb video tutorials created by [James Willett](https://youtu.be/pPEUhfTZswc?si=AjoyIaM5Ig7MZdgo).

## Why I Chose MkDocs 🤔

After exploring several blogging platforms, I settled on MkDocs for its simplicity, flexibility, and Markdown support. Unlike WordPress or Ghost, MkDocs is lightweight and doesn't require a database. The Material theme provides beautiful out-of-the-box styling, and since everything is in Markdown, I can easily version control my content using Git.

## Prerequisites 🛠️

Before we begin, ensure you have the following installed:

- **Python 3.x** – MkDocs is a Python-based tool. You can check if Python is installed by running:
  
  ```sh
  python --version
  ```

  If Python is not installed, download it from [python.org](https://www.python.org/downloads/) and follow the installation instructions.

- **pip** – Python's package manager. It usually comes with Python, but you can verify it with:
  
  ```sh
  pip --version
  ```

- **Git** – To manage version control and push changes to GitHub. You can install Git from [git-scm.com](https://git-scm.com/downloads).

## Setting Up Your Environment 🌱

### Creating a Virtual Environment (Recommended)

It's a good practice to use a **virtual environment (venv)** when working with Python projects to avoid dependency conflicts:

1. Navigate to your project directory:

   ```sh
   cd /path/to/your/project
   ```

2. Create a virtual environment:

   ```sh
   python -m venv venv
   ```

3. Activate the virtual environment:

!!! note "Choose your OS"
=== "On Windows"
     ```sh
     venv\Scripts\activate
     ```
=== "On macOS/Linux"
     ```sh
     source venv/bin/activate
     ```

### Installing MkDocs

Once your virtual environment is activated, install MkDocs:

```sh
pip install mkdocs
```

To verify the installation, run:

```sh
mkdocs --version
```

If you see the installed version displayed, the installation was successful.

## Creating a New MkDocs Project 🏗️

Navigate to the directory where you want to create your blog and run:

```sh
mkdocs new my-blog
cd my-blog
```

This creates a basic MkDocs project structure, including:

- A default `mkdocs.yml` configuration file
- A `docs/` directory containing an `index.md` file

## Installing Dependencies ⚙️

To enhance your MkDocs site with additional features, create a `requirements.txt` file in the root of your project:

```sh
# Requirements for core
jinja2~=3.0
markdown~=3.2
mkdocs~=1.6
mkdocs-material~=9.5.46
mkdocs-material-extensions~=1.3
pygments~=2.16
pymdown-extensions~=10.2

# Requirements for plugins
babel~=2.10
colorama~=0.4
paginate~=0.5
regex>=2022.4
requests~=2.26

# Additional Material and MkDocs plugins
mkdocs-glightbox~=0.4.0
mkdocs-get-deps~=0.2.0
mkdocs-minify-plugin~=0.8.0
mkdocs-git-committers-plugin-2~=2.4.1
mkdocs-git-revision-date-localized-plugin~=1.3.0
mkdocs-rss-plugin~=1.16.0
```

Install these dependencies with:

```sh
pip install -r requirements.txt
```

## Customizing Your Blog ✨

### Basic Configuration

The `mkdocs.yml` file is the configuration file for your blog. Open it in a text editor and modify it:

```yaml
site_name: My Tech Blog
site_description: A blog documenting my projects and insights
site_author: Your Name
repo_url: https://github.com/yourusername/my-blog
```

### Adding the Material Theme

The Material theme provides a clean, responsive design for your blog:

```yaml
theme:
  name: material
  palette:
    primary: indigo
    accent: indigo
  features:
    - navigation.tabs
    - navigation.top
    - search.suggest
    - search.highlight
```

### Setting Up Blog Features

To turn your MkDocs site into a proper blog, add the blog plugin configuration:

```yaml
plugins:
  - blog:
      blog_dir: blog
      post_date_format: yyyy-MM-dd
      post_url_format: "{date}/{slug}"
  - search
  - rss:
      match_path: blog/posts/.*
      date_from_meta:
        as_creation: date
      categories:
        - categories
```

## Creating Blog Posts 📰

### Folder Structure

Create the following structure for your blog posts:

```
docs/
├── blog/
│   ├── posts/
│   │   ├── 2025-03-01-hello-world.md
│   │   └── 2025-03-09-setting-up-mkdocs.md
│   └── index.md
└── index.md
```

### Post Frontmatter

Each blog post should have frontmatter at the top, like this:

```yaml
---
title: "Your Post Title"
date: 2025-03-09
authors:
  - yourname
description: "A brief description of your post."
categories:
  - Category1
  - Category2
tags:
  - tag1
  - tag2
---

# Your Post Title

Content goes here...
```

### Adding Images and Media

To include images in your posts:

1. Create an `assets` folder in your `docs` directory:

   ```
   docs/
   ├── assets/
   │   └── images/
   │       └── screenshot.png
   ```

2. Reference the image in your Markdown:

   ```markdown
   ![Screenshot of MkDocs site](../assets/images/screenshot.png)
   ```

## Running MkDocs Locally 🖥️

To preview your blog locally and check how it looks before publishing, run:

```sh
mkdocs serve
```

This will start a local web server. Open your browser and go to:

```
http://127.0.0.1:8000/
```

to view your blog. The server will automatically reload when you make changes to your files.

## Deploying to GitHub Pages 🚀

### Initialize a Git Repository

First, navigate to your project folder and initialize a Git repository:

```sh
git init
git add .
git commit -m "Initial commit"
```

### Create a GitHub Repository

1. Go to [GitHub](https://github.com/) and log in.
2. Click the **"+"** button in the top-right and select **"New repository"**.
3. Enter a **Repository name** (e.g., `my-blog`).
4. Choose **Public** or **Private**, based on your preference.
5. **DO NOT** initialize with a README, `.gitignore`, or license (since we are pushing an existing project).
6. Click **"Create repository"**.

After creating the repository, copy the repository URL (e.g., `https://github.com/yourusername/my-blog.git`).

### Link Your Local Repository to GitHub

Now, link your local project to the GitHub repository:

```sh
git remote add origin https://github.com/yourusername/my-blog.git
git branch -M main
git push -u origin main
```

### Deploy Your Blog to GitHub Pages

To publish your blog on GitHub Pages, run:

```sh
mkdocs gh-deploy
```

This command builds your MkDocs project and pushes the static files to the `gh-pages` branch of your repository.

### Enable GitHub Pages in Repository Settings

1. Go to your GitHub repository.
2. Navigate to **Settings > Pages**.
3. Under **Branch**, select `gh-pages` and click **Save**.
4. Your site will be live at `https://yourusername.github.io/my-blog/` (Note: It may take a few minutes for your site to appear live after deployment).

## Enhancing Your Development Experience 💻

For an easier development experience, I recommend using **Visual Studio Code (VS Code)**. You can install it from [code.visualstudio.com](https://code.visualstudio.com/).

### Recommended VSCode Extensions

- **Python** (for virtual environment support)
- **Markdown Preview Enhanced** (for writing and previewing Markdown files)
- **YAML** (for editing `mkdocs.yml`)
- **Material Theme Icons** (for a nicer file tree visualization)

## Troubleshooting Common Issues 🔧

### Site Not Deploying

If your site isn't appearing after running `mkdocs gh-deploy`:

- Check if you've configured GitHub Pages in your repository settings
- Ensure you've pushed your changes to the correct branch
- Wait a few minutes as GitHub Pages deployment can take time

### Styling Issues

If your theme isn't applying correctly:

- Verify the theme is installed (`pip install mkdocs-material`)
- Check for syntax errors in your `mkdocs.yml` file
- Try clearing your browser cache

## Conclusion 🎉

Setting up MkDocs is straightforward, and with GitHub Pages, you can host your blog for free. The Material theme provides excellent styling out of the box, and with the right plugins, you can create a fully-featured blog with minimal effort.

In future posts, I'll cover more customizations, themes, and plugins to enhance your MkDocs blog. Stay tuned!

---
