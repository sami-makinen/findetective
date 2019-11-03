# Spy
Spy is a languge detection algorithm tuned specially for Finnish.
Spy implements Trie data structure for dictionary, LIGA algorithm for language
detection and extension to String for Finnish hyphenation. String extension
has also trigram generation but Finnish hyphenation seems to work better.

## Usage
require 'spy'
spy = Spy::Spy.new
spy.loadall
spy.challenge

## Installation
Add this line to your application's Gemfile:

```ruby
gem 'spy'
```

And then execute:
```bash
$ bundle
```

Or install it yourself as:
```bash
$ gem install spy
```

After installing dictionary and detection models are built with following procedure:
1. Fetch Finnish word net from https://korp.csc.fi/download/FinnWordNet/v2.0/FinnWordNet-2.0.zip (36M)
2. Fetch Finnish Tree Bank from http://www.ling.helsinki.fi/kieliteknologia/tutkimus/treebank/sources/ftb3.tgz (635MB)
3. Fetch English-Estonian corpus from Finnish Tree Bank https://data.europa.eu/euodp/en/data/dataset/elrc_304
4. Extract packages to somewhere. Note: extracted ftb3 takes 3.8GB!
5. Run
```bash
$ rake "spy:builddict[/path/to/FinnWordNet-2.0, /path/to/ftb3.conllx]"
```
6. Run
```bash
$ rake "spy:buildmodel[/path/to/europarl-v7.fi-en.fi, /path/to/europarl-v7.et-en.et]"
```

## Contributing

Author Sami Mäkinen <sami.o.makinen@gmail.com>

Sources of the data and knowledge:
University of Helsinki (2012). The Downloadable Version of the Finnish TreeBank 3 [text corpus]. Retrieved from http://urn.fi/urn:nbn:fi:lb-2016042601
https://data.europa.eu/euodp/en/data/dataset/elrc_304
European Parliament Proceedings Parallel Corpus 1996-2011, http://www.statmt.org/europarl/
https://korp.csc.fi/download/FinnWordNet/v2.0/
http://xml.coverpages.org/TMX-SpecV13.html
CONLL-X format (http://nextens.uvt.nl/~conll/#dataformat)
Tromp, Erik & Pechenizkiy, Mykola. (2011). Graph-Based N-gram Language Identification on Short Texts. Proceedings of Benelearn 2011. 27-34.
Panich, Leonid, Stefan Conrad and Martin Mauve. “Comparison of Language Identification Techniques.” (2015).
https://github.com/rest-client/rest-client
https://ruby-doc.org/core-2.6.5/String.html
http://www.kielitoimistonohjepankki.fi/haku/tavutus/ohje/153

## License
The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
