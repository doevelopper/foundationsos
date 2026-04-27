<a name="___top"></a>
```txt
 CCCCC  PPPPPP  PPPPPP     BBBBB   DDDDD   DDDDD       1   00000   1  
CC    C PP   PP PP   PP    BB   B  DD  DD  DD  DD     111 00   00 111 
CC      PPPPPP  PPPPPP     BBBBBB  DD   DD DD   DD     11 00   00  11 
CC    C PP      PP         BB   BB DD   DD DD   DD     11 00   00  11 
 CCCCC  PP      PP         BBBBBB  DDDDDD  DDDDDD     111  00000  111
........................................................................................
....01000011 01010000 01010000  01000010 01000100 01000100  00110001 00110000 00110001 
                                  --A.H.L
```
[![Language](https://img.shields.io/badge/language-C++-blue.svg)](https://isocpp.org/)
[![Maintenance](https://img.shields.io/badge/Maintained%3F-yes-green.svg)](https://gitlab.com/doevelopper/cppbdd101/tree/develop)
# cppbdd101

A simple template for a correct c++ project layout and tools for delivering good artifact trough good development practices. 
This using open sources tools ONLY

<a name="project_versioning"></a> 
## [ Project Versioning &#9650;](#___top "click to go to top of document")
It's inspired by [GitFlow](http://nvie.com/posts/a-successful-git-branching-model/), [SemVer 2.0.0](https://semver.org/), [GitVersion](https://gitversion.readthedocs.io/en/latest/).
### Base agreements:
* The stable versions of the package **should be** are announced by the developer in **master** branches
* Unstable versions of the package **could be** auto computed by the git environment on CI server
* Development **should be** carried out within the framework of the [GitFlow](http://nvie.com/posts/a-successful-git-branching-model/),
and package versions **should be** based on [![Semver](http://img.shields.io/SemVer/2.0.0.png)](http://semver.org/spec/v2.0.0.html).

As CI server can publish the package as _unstable_ (_prerelease_) and _stable_ version.
For definition to be performed correctly, it is necessary to observe **GitFlow** branching model.

* **master** - package version remains as is `X.Y.Z`
* **develop** - package version is `X.(Y+1).0-alpha.{commits}`
* **feature/*** - package version is `X.(Y+1).0-feature-{hash}.{commits}`
* **release/vX'.Y'.Z'** - package version is `X'.Y'.Z'-rc.{commits}`
* **hotfix/*** - package version is `X.Y.(Z+1)-beta.{commits}`

`X` - current major version declarate in package.json

`Y` - current minor version declarate in package.json

`Z` - current patch version declarate in package.json

`{hash}` - it's first feature branch commit (generic commit from develop and feature branch)

`{commits}` - quantity commits from branch start.

Prerelease path could be override with config file `git-semver-info.json`.
This config file should be place into **current work directory**.

Config file content (default value):

```json
{
  "prerelease": {
    "develop": "alpha.${developBranchCommitsCount}",
    "feature": "feature-${firstFeatureCommitSha}.${featureBranchCommitsCount}",
    "hotfix": "beta.${hotfixBranchCommitsCount}",
    "release": "rc.${releaseBranchCommitsCount}"
  }
}
```

### Example

The final semantic version of the package looks like:

```
<major>.<minor>.<patch>-<prerelease>+<build-number>
```
I.e For branch `feature/feature-name` and package version `1.2.3`,
it's prerelease version looks like:

```
1.2.3-feature-3kn3erb.13+42
```

<a name="Developement_status"></a> 
## [ Developement status &#9650;](#___top "click to go to top of document")

Branch   | Gitlab-CI | Travis | Build |  Tests  | Integration Test | Coverage | Documentation |
|--------|-----------|--------|-------|---------|------------------|----------|---------------|
|[__master__](https://gitlab.com/doevelopper/cppbdd101/tree/master) | [![pipeline status](https://gitlab.com/doevelopper/cppbdd101/badges/master/pipeline.svg)](https://gitlab.com/doevelopper/cppbdd101/commits/master) |-|-|-|-|[![coverage report](https://gitlab.com/doevelopper/cppbdd101/badges/master/coverage.svg)](https://gitlab.com/doevelopper/cppbdd101/commits/master)| ![tbd](https://img.shields.io/badge/development%20status-active-green.svg)
|[__develop__](https://gitlab.com/doevelopper/cppbdd101/tree/develop)
|[__release__](https://gitlab.com/doevelopper/cppbdd101/tree/develop)

<a name="[Binaries_Distribution_management"></a>
## [Binaries Distribution management &#9650;](#___top "click to go to top of document")
| Distribution  Chanel | Description |
|----------------------|-------------|
| :bangbang: [__Nightly__](#www.tbd.acme) | Builds created out of the central repository every night, packaged up every night for bleeding-edge testers to install and test.These are not qualified by QA.                                                                                                      |
| :soon: [__Aurora__](#www.tbd.acme)  | Builds created out of the aurora repository, which is synced from central repository every weeks.There is a small amount of QA at the start of the 1 week period before the updates are offered.as such its status is roughly "experimental".  |
| :interrobang: [__Beta__](#www.tbd.acme)    | Builds created out of the master repository, qualified by QA as being of sufficient quality to release to beta users.                                                                         |
| :heavy_check_mark: [__Release__](#www.tbd.acme) | Builds created out of the release repository, qualified by QA as being of sufficient quality to release to hundreds of millions of people.                                                    |


<a name="Limitations"></a>
# [Limitations](#___top "click to go to top of document")


<a name="in_progress"></a>
# [Features under development &#9650;](#___top "click to go to top of document")

# Copyright Notice and License

### Software licences
© 2011-2018 A.H.L , Inc. All Rights Reserved.
Copyright the authors and contributors. See individual source files
for details.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions
 are met:
 1. Redistributions of source code must retain the above copyright
    notice, this list of conditions and the following disclaimer.
 2. Redistributions in binary form must reproduce the above copyright
    notice, this list of conditions and the following disclaimer in the
    documentation and/or other materials provided with the distribution.

 THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
 ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
 FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 SUCH DAMAGE.

- Code and documentation copyright 2011-2018 A.H.L, Inc.
- Code are released under [![License](https://img.shields.io/badge/license-Apache%20license%202.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)
- Docs are released under [![License: CC BY-NC-SA 4.0](https://img.shields.io/badge/License-CC%20BY--NC--SA%204.0-lightgrey.svg)](https://creativecommons.org/licenses/by-nc-sa/4.0/)
- CI/CD Scripts are under [![License: LGPL v3](https://img.shields.io/badge/License-LGPL%20v3-blue.svg)](http://www.gnu.org/licenses/lgpl-3.0)  


