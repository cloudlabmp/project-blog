---
title: "Enhancing My MkDocs Blog with Custom Features"
date:
  created: 2025-02-25
  updated: 2025-02-25
authors:
  - matthew
description: "A guide to customizing an MkDocs blog with navigation links, social media icons, an announcement bar, and a custom footer."
categories:
  - MkDocs
  - Customization
  - Blogging
  - Tech
tags:
  - mkdocs
  - material-theme
  - customization
  - web-development
---

# Enhancing My MkDocs Blog with Custom Features 🚀

Once I set up my MkDocs blog, I wanted to personalize it by adding **navigation links, social media icons, an announcement bar, and a custom footer**. These enhancements improve user experience, branding, and site functionality. This post walks through each customization step with code examples and configurations.

## **🔗 Adding Navigation Links to the Header**

To provide quick access to key profiles and resources, I added navigation links.

### **📝 Update `mkdocs.yml`**

```yaml
nav:
  - Home: index.md
  - Blog: blog.md
  - About: about.md
  - Contact: contact.md
  - GitHub: https://github.com/cloudlabmp
  - LinkedIn: https://linkedin.com/in/matthew-pollock-76831920/
  - Website: https://profile.pollockweb.com
```

This allows visitors to access my GitHub, LinkedIn, and personal site from the navigation menu.

---

## **🌐 Adding Social Media Icons to the Header**

Instead of plain text links, I enabled **social media icons** in the header.

### **📝 Update `mkdocs.yml`**

```yaml
extra:
  social:
    - icon: fontawesome/brands/github
      link: https://github.com/cloudlabmp
    - icon: fontawesome/brands/linkedin
      link: https://linkedin.com/in/matthew-pollock-76831920/
    - icon: fontawesome/solid/globe
      link: https://profile.pollockweb.com
```

These icons now appear in the **top-right** of the header.

---

## **📢 Enabling the Announcement Bar**

A **dismissible announcement bar** allows for important updates.

### **📝 Update `mkdocs.yml`**

```yaml
theme:
  name: material
  features:
    - announce.dismiss
```

### **📝 Customize `overrides/main.html`**

```html
{% extends "base.html" %}

{% block announce %}
  <div class="announcement-content">
    <p>Welcome to my blog! Connect with me:</p>
    <a href="https://github.com/cloudlabmp" target="_blank">
      <i class="fab fa-github fa-2x"></i>
    </a>
    <a href="https://www.linkedin.com/in/matthew-pollock-76831920/" target="_blank">
      <i class="fab fa-linkedin fa-2x"></i>
    </a>
  </div>
{% endblock %}
```

---

## **📌 Customizing the Footer**

To personalize the footer, I added a **copyright notice** and **aligned social media icons**.

### **📝 Customize `overrides/partials/footer.html`**

```html
{% block content %}
  <div class="custom-footer">
    <div class="custom-footer-left">
      <p>Copyright &copy; 2025 Matthew Pollock</p>
    </div>
    <div class="custom-footer-right">
      <a href="https://github.com/cloudlabmp" target="_blank">
        <i class="fab fa-github"></i>
      </a>
      <a href="https://linkedin.com/in/matthew-pollock-76831920/" target="_blank">
        <i class="fab fa-linkedin"></i>
      </a>
      <a href="https://profile.pollockweb.com" target="_blank">
        <i class="fas fa-globe"></i>
      </a>
    </div>
  </div>
{% endblock %}
```

### **🎨 Custom Footer Styling (`extra.css`)**

```css
/* Custom footer styling */
.custom-footer {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 15px 20px;
  width: 100%;
  background: var(--md-default-bg-color);
  border-top: 1px solid var(--md-default-fg-color--light);
}

.custom-footer-left {
  text-align: left;
  font-size: 0.9em;
  color: var(--md-default-fg-color);
}

.custom-footer-right {
  display: flex;
  gap: 15px;
}

.custom-footer-right a {
  font-size: 1.8em;
  color: var(--md-default-fg-color);
  transition: transform 0.2s ease-in-out;
}

.custom-footer-right a:hover {
  transform: scale(1.2);
  color: #673AB7; /* Deep Purple (Accent Color) */
}

/* Add padding to the bottom of the page */
.md-content {
  padding-bottom: 40px;
}
```

---

## **🎉 Final Results**

✔ **Clickable social media icons** in the header and footer  
✔ **A dismissible announcement bar** for updates  
✔ **Navigation links** to external sites  
✔ **A fully customized footer** with copyright and icons  
✔ **Refined color scheme** using deep purple accents  

Each of these enhancements has made my MkDocs blog more **functional, visually appealing, and user-friendly**. If you’re looking to implement similar customizations, these steps should get you started! 🚀

---
