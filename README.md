# pseudo2graphml

[![Build Status](https://travis-ci.org/kitomer/pseudo2graphml.svg)](https://travis-ci.org/kitomer/pseudo2graphml)
[![Inline docs](http://inch-ci.org/github/kitomer/pseudo2graphml.svg?branch=master)](http://inch-ci.org/github/kitomer/pseudo2graphml)
[![HitCount](http://hits.dwyl.io/kitomer/pseudo2graphml.svg)](http://hits.dwyl.io/kitomer/pseudo2graphml)

convert pseudocode in text to yEd graphml

## Features

- write flow in pseudocode that is easy to read and change and version
- convert it and auto-layout it using the free and powerful yEd diagram editor for generating beautiful diagram graphics
- useful for documentation and development

## Getting Started

Create a pseudocode file, for example:

      start
      do stuff
      if something happens
        do that
      else
        do other things
        even this
        if bad things happens
          finish error
        elsend
      end
      more to do
      finish success

Convert the input pseudocode file to a yEd graphml file using pseudo2graphml in a terminal:

      $ pseudo2graphml.pl myfile.pseudo myfile.graphml

Open yEd and open the graphml file. Then auto-layout it using the "flowchart" mode. Save and you are done.

### Dependencies / Prerequisites

- Perl 5+
- Perl modules:
  - yEd::Document

### Installing / Deployment / Integration

- Perl is probably already there, on Windows you might use Strawberry Perl distro
- yEd::Document can be installed using the CPAN terminal tool or your distros package manager

## Used by

- ?

## Built With

- Perl

## Contributing

[![Contributions welcome](https://img.shields.io/badge/contributions-welcome-brightgreen.svg?style=flat)](https://github.com/kitomer/pseudo2graphml/issues)

A dedicated contributing document is coming soon.

## Versioning

- major.minor
- higher = newer

## Authors

* **Tom Kirchner** - *Initial work and maintainer* - [kitomer](https://github.com/kitomer)

See also the list of [contributors](https://github.com/kitomer/pseudo2graphml/contributors)
who participated in this project.

## License

This project is licensed under the GNU General Public License (version 3 or later) -
see the [LICENSE](LICENSE) file for details

## Acknowledgments

Coming soon.

## Similar projects

- https://github.com/knsv/mermaid
- https://github.com/isuka/C2Flow
- https://github.com/ochko/markdoc

