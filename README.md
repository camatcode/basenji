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

  <a href="https://github.com/camatcode/basenji/actions?query=branch%3Amain++">
    <img alt="ci status" src="https://github.com/camatcode/basenji/workflows/ci/badge.svg">
  </a>
  <a href='https://coveralls.io/github/camatcode/basenji?branch=main'>
    <img src='https://coveralls.io/repos/github/camatcode/basenji/badge.svg?branch=main' alt='Coverage Status' />
  </a>

<a href="https://mastodon.social/@scrum_log" target="_blank" rel="noopener noreferrer">
    <img alt="Mastodon Follow" src="https://img.shields.io/badge/mastodon-%40scrum__log%40mastodon.social-purple?color=6364ff">
  </a>

</p>


> [!WARNING]  
> This project is under active development.



## Table of Contents

- [Features / Running Roadmap](#features--running-roadmap)
- [Deep Backlog](#deep-backlog)
- [Attributions](#attributions)


### Features / Running Roadmap

* Supported formats:  CBZ, CBR, CBT, CB7, and PDF
* Optimizes pages to improve read times on-the-fly
* Efficient CRUD, filtering, sorting
  *  Intelligently pre-fetches pages, so you're *never* waiting on it to send you the next page
* APIs / Services
  * JSON:API
  * GraphQL
  * FTP interface (for legacy third-party clients without HTTP connectivity)
* Powerful background processing that
  * Organizes deeply nested collections of comics
  * Creates image previews, extracts metadata, handles the comic life cycle
  * Stress tested with 49.9 GB of comics with 2700 items
  * Stores optimized versions to save you disk space
  * Won't run expensive background jobs when the app is in use (thanks, [Phoenix.Tracker](https://hexdocs.pm/phoenix_pubsub/Phoenix.Tracker.html)!)
  * Finds and resolves duplicates
* Front-End
  * Search, List, Explore, Filter
  * Smart full screen viewer
  * 🚧 Continue making  it more ergonomic
  * 🚧 Admin pages

### Attributions

* <a href="https://www.flaticon.com/free-icons/purebred" title="purebred icons">Purebred icons created by Chanut-is-Industries - Flaticon</a>
