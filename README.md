# Hammerspoon
[![CI](https://github.com/Hammerspoon/hammerspoon/workflows/CI/badge.svg)](https://github.com/Hammerspoon/hammerspoon/actions?query=workflow%3ACI)
[![codecov.io](https://codecov.io/github/Hammerspoon/hammerspoon/coverage.svg?branch=master)](https://codecov.io/github/Hammerspoon/hammerspoon?branch=master)
[![Downloads current release](https://img.shields.io/github/downloads/Hammerspoon/hammerspoon/latest/total.svg)](https://github.com/Hammerspoon/hammerspoon/releases)
[![Downloads all releases](https://img.shields.io/github/downloads/Hammerspoon/hammerspoon/total.svg?maxAge=2592000)](https://github.com/Hammerspoon/hammerspoon/releases)
[![Latest tag](https://img.shields.io/github/tag/Hammerspoon/hammerspoon.svg)](https://github.com/Hammerspoon/hammerspoon/tags)
[![Latest release](https://img.shields.io/github/release/Hammerspoon/hammerspoon.svg)](https://github.com/Hammerspoon/hammerspoon/releases/latest)

Discord: [Click to join](https://discord.gg/vxchqkRbkR)

## What is Hammerspoon?

This is a tool for powerful automation of OS X. At its core, Hammerspoon is just a bridge between the operating system and a Lua scripting engine.

What gives Hammerspoon its power is a set of extensions that expose specific pieces of system functionality, to the user. With these, you can write Lua scripts to control many aspects of your OS X environment.

## How do I install it?

### Manually

 * Download the [latest release](https://github.com/Hammerspoon/hammerspoon/releases/latest)
 * Drag `Hammerspoon.app` from your `Downloads` folder to `Applications`

### Homebrew

  * `brew install hammerspoon --cask`

## What next?

Out of the box, Hammerspoon does nothing - you will need to create `~/.hammerspoon/init.lua` and fill it with useful code. There are several resources which can help you:
 * [Getting Started Guide](https://www.hammerspoon.org/go/)
 * [API docs](https://www.hammerspoon.org/docs/)
 * [FAQ](https://www.hammerspoon.org/faq/)
 * [Sample Configurations](https://github.com/Hammerspoon/hammerspoon/wiki/Sample-Configurations) supplied by various users
 * [Contribution Guide](https://github.com/Hammerspoon/hammerspoon/blob/master/CONTRIBUTING.md) for developers looking to get involved
 * An IRC channel for general chat/support/development (#hammerspoon on Libera)
 * [Google Group](https://groups.google.com/forum/#!forum/hammerspoon/) for support

## What is the history of the project?

Hammerspoon is a fork of [Mjolnir](https://github.com/mjolnirapp/mjolnir). Mjolnir aims to be a very minimal application, with its extensions hosted externally and managed using a Lua package manager. We wanted to provide a more integrated experience.

## What is the future of the project?

Our intentions for Hammerspoon broadly fall into these categories:
 * Ever wider coverage of system APIs in Extensions
 * Tighter integration between extensions
 * Smoother user experience

