---
title: "Setting Up MkDocs for Your Blog"
draft: true
date:
  created: 2025-03-05
  updated: 2025-03-05
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

# Setting Up MkDocs for Your Blog

If you're looking for a simple yet powerful way to create and manage your documentation or blog, **MkDocs** is a fantastic option. In this post, I'll walk you through the steps to set up MkDocs for your blog and get it hosted on GitHub Pages.

All of the steps covered in this guide are available in the [MKDocs Documentation](https://squidfunk.github.io/mkdocs-material/getting-started/) or via the superb video tutorials created by [James Willett](https://youtu.be/pPEUhfTZswc?si=AjoyIaM5Ig7MZdgo)

## Prerequisites

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

## Setting Up a Virtual Environment (Recommended)

It's a good practice to use a **virtual environment (venv)** when working with Python projects to avoid dependency conflicts. To set up a virtual environment:

  Navigate to your project directory:

   ```sh
   cd /path/to/your/project
   ```

  Create a virtual environment:

  ```sh
  python -m venv venv
  ```

  Activate the virtual environment:

!!! note "Choose your OS"
=== "On Windows"
     ```sh
     venv\Scripts\activate
     ```
=== "On macOS/Linux"
     ```sh
     source venv/bin/activate
     ```

  Once activated, install MkDocs inside the virtual environment:

   ```sh
   pip install mkdocs
   ```

To deactivate the virtual environment, run:

```sh
deactivate
```

## Install `requirements.txt`

Create a new file in the root of your working directory called `requirements.txt`
Add the following code block to the file and save it

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

From your terminal run the following command to install the prereqs.

```py
python install -r requirements.txt
```

## Install MkDocs

First, install MkDocs using `pip`:

```py
pip install mkdocs
```

To verify the installation, run:

```sh
mkdocs --version
```

If you see the installed version displayed, the installation was successful.

## Create a New MkDocs Project

Navigate to the directory where you want to create your blog and run:

```sh
mkdocs new my-blog
cd my-blog
```

This creates a basic MkDocs project structure, including a default `mkdocs.yml` configuration file and a `docs/` directory containing an `index.md` file.

## Customize `mkdocs.yml`

The `mkdocs.yml` file is the configuration file for your blog. Open it in a text editor and modify the site name:

```yaml
site_name: My Tech Blog
site_description: A blog documenting my projects and insights
repo_url: https://github.com/yourusername/my-blog
```

### Adding a Theme

You can also add a theme for better styling. For example, to use the **Material for MkDocs** theme, first install it:

```py
pip install mkdocs-material
```

Then update `mkdocs.yml` to use the new theme:

```yaml
theme:
  name: material
```

## Run MkDocs Locally

To preview your blog locally and check how it looks before publishing, run:

```sh
mkdocs serve
```

This will start a local web server. Open your browser and go to:

```sh
http://127.0.0.1:8000/
```

to view your blog.

## Deploy to GitHub Pages

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
4. Your site will be live at `https://yourusername.github.io/my-blog/`.

## Note: Using an IDE

For an easier development experience, I recommend using **Visual Studio Code (VS Code)**. You can install it from [code.visualstudio.com](https://code.visualstudio.com/).

### Recommended VSCode Extensions

- **Python** (for virtual environment support)
- **Markdown Preview Enhanced** (for writing and previewing Markdown files)
- **YAML** (for editing `mkdocs.yml`)

## Conclusion

Setting up MkDocs is straightforward, and with GitHub Pages, you can host your blog for free. In future posts, I'll cover more customizations, themes, and plugins to enhance your MkDocs blog.

---

📌 *Published on:* 2025-03-05
