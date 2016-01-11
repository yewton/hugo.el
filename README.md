# hugo.el #

Some helper functions for creating a Website with [Hugo](https://gohugo.io/).

## Installation ##

See [marmalade-repo - for all your EmacsLisp needs](https://marmalade-repo.org/) and follow the instruction "how to use it".

Then execute the following command:

```
package-install hugo
```

## Usage ##

Customize `hugo-sites-dir` where generated Hugo sites are placed.

Example:

```
(custom-set-variables
 '(hugo-sites-dir (expand-file-name "~/HugoSites")))
```

### `hugo-new-site` ###

Execute `hugo new site` and `git init`.

### `hugo-find-site` ###

Find a site directory.

### `hugo-new-content` ###

Add a new content to current site.

### `hugo-start-server` ###

Start hugo-server for current site.

You can then `hugo-open-brower` to open the site with default browser.

`hugo-stop-server` to stop running server.

### `hugo-install-theme` ###

Install a theme to current site.

Themes are added as a git submodule.
