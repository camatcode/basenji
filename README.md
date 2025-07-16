<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/camatcode/basenji/refs/heads/main/assets/basenji-logo-dark2.png">
    <source media="(prefers-color-scheme: light)" srcset="https://raw.githubusercontent.com/camatcode/basenji/refs/heads/main/assets/basenji-logo-light2.png">
    <img alt="basenji logo" src="https://raw.githubusercontent.com/camatcode/basenji/refs/heads/main/assets/basenji-logo-light2.png" width="320">
  </picture>
</p>

<p align="center">
  A modern, self-hostable comic book reader with the features you expect and a few that'll surprise you.
</p>


<p align="center">
  <a href="https://hex.pm/packages/basenji">
    <img alt="Hex Version" src="https://img.shields.io/hexpm/v/basenji.svg">
  </a>

  <a href="https://hexdocs.pm/basenji">
    <img alt="Hex Docs" src="http://img.shields.io/badge/hex.pm-docs-green.svg?style=flat">
  </a
  -->
  
  <a href="https://opensource.org/licenses/Apache-2.0">
    <img alt="Apache 2 License" src="https://img.shields.io/hexpm/l/oban">
  </a>

<a href="https://mastodon.social/@scrum_log" target="_blank" rel="noopener noreferrer">
    <img alt="Mastodon Follow" src="https://img.shields.io/badge/mastodon-%40scrum__log%40mastodon.social-purple?color=6364ff">
  </a>

</p>


> [!WARNING]  
> This project is under active, daily development.



## Table of Contents

- [Features / Running Roadmap](#features--running-roadmap)
- [Deep Backlog](#deep-backlog)
- [Attributions](#attributions)


### Features / Running Roadmap

* ✅ Supports CBZ, CBR, CBT, CB7, and PDF comic book formats
* ✅ Optimizes pages to improve read times on-the-fly
* ✅ Efficent CRUD, filtering, sorting
  *  🚧 In Progress: Test that its faster than every other comic book reader, especially under load
* ✅ APIs / Services
  * ✅ JSON:API
  * ✅ GraphQL
  * ✅ FTP interface (for legacy third-party clients without HTTP connectivity)
* ✅ Powerful background processing that
  * ✅ Organizes deeply nested collections of comics
  * ✅ Creates image previews, extracts metadata, handles the comic life cycle
  * ✅ Stress tested with 49.9 GB of comics with 2700 items
  * ✅ Stores optimized versions to save you disk space
* Front-End
  *  ✅ Search, List, Explore, Filter, Viewer
  *  ✅ Smart full screen viewer
  *  🚧 In Progress: Continue making  it more ergonomic 
* 🚧 Rest is in development

### ⏸️ Deep Backlog

* ⏸️ [Ebook Detection using visual analysis and fallback OCR](https://github.com/camatcode/basenji/pull/44)
  * Under heavy stress testing, this strategy is very good at *confirming* that a comic is a comic; but is only about 60% accurate at *confirming* a file is a text-heavy ebook
  * Edge cases include - poetry, poorly scanned pages, misaligned text blocks, interview formats, magazines

### Attributions

* <a href="https://www.flaticon.com/free-icons/purebred" title="purebred icons">Purebred icons created by Chanut-is-Industries - Flaticon</a>
