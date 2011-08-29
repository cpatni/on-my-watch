# On My Watch

[On My Watch](http://github.com/rubyorchard/on-my-watch) is a sinatra app deployable on heroku to search your watched
repositories on github.

#### On My Watch features:

 * Single User/Multi User support
 * Deployable on heroku with no initial startup cost

#### Dependencies
 * Mongodb
 * indextank
 * Sinatra, ERB

#### Installation

```bash
#Install and run mongodb
cp config/app.json.sample config/app.json
#modify config/app.json
gem install bundler
bundle
bunle exec shotgun
```

### Other Stuff
--------

 * Author::  Chandra Patni
 * License:: Original code Copyright 2011 by Chandra Patni.
             Released under an MIT-style license.  See the LICENSE  file
             included in the distribution.

#### Warranty
--------

This software is provided "as is" and without any express or
implied warranties, including, without limitation, the implied
warranties of merchantibility and fitness for a particular
purpose.
