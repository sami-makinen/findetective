# coding: utf-8
require "spy/railtie"
require "spy/core_ext"
require 'rexml/document'
require 'json'
require 'rest-client'
require 'singleton'

module Spy
  FinnWordNetUrl='https://korp.csc.fi/download/FinnWordNet/v2.0/FinnWordNet-2.0.zip'
  
  QuadVowels= ("[" + String::Vowels + "]") * 4
  QuadConsonants=("[^ ." + String::Vowels + "]") * 4
  DictionaryFile='sanasto.txt'

  class TrieNode
    def children
      @children
    end
    
    def initialize
      @children = [nil] * String::Alphabet.length
    end
  end
  
  class Trie
    
    def load(filename)
      File.foreach(filename) {|line|
        insert(line.strip)
      }
    end
    
    def save(filename)
      out=File.new(filename, File::CREAT|File::RDWR,0644)
      each_word {|word|
        out << word << "\n"
      }
      out.close
    end
    
    def each_word
      # note: yield does not seem to work with recursive calls
      #       so this is iterative implementation using explicit stack.
      pos=0
      node=root
      stack=[]
      while not node.nil?
        found=false
        pos.upto(String::Alphabet.length-1) {|i|
          next if node.children[i].nil?
          found=true
          stack.push([i, node])
          node = node.children[i]
          pos = 0
          break
        }
        
        next if found
        
        yield(stack.map{|e| String::Characters[e.first]}.join) unless node.children[String::Alphabet.length].nil?
        
        if stack.empty?
          node = nil
        else
          # restore saved position
          pos,node = stack.pop
          pos = pos+1
        end
      end
    end
    
    def wordcount
      @wordcount
    end
    
    def initialize
      @root = TrieNode.new
      @wordcount = 0
    end
    
    def root
      @root
    end
    
    def insert(word)
      return if word.nil? || word.empty?
      node = root
      word.chars.each{|ch|
        
        if ch == '#' || ch == '-' # 'yhdyssana'
          next
        end
        
        i = String::Characters.index(ch)
        return if i.nil?
        #   print "debug trie: insert " + ch + " (" + i.to_s + ")\n" if word == 'kunnalle'
        chnode = node.children[i]
        if chnode.nil?
          chnode = TrieNode.new
          node.children[i] = chnode
        end
        node = chnode
      }
      
      # mark end of word with pointer to root
      if node.children[String::Characters.length].nil?
        node.children[String::Characters.length] = root
        @wordcount = @wordcount + 1
      end
    end
    
    def contains?(word)
      node = root
      word.chars.each{|ch|
        #    print "lookup: " + ch + "\n"
        if ch == '#' || ch == '-'
          next
        end
        
        i = String::Characters.index(ch)
        return false if i.nil?
        #      print "debug trie: lookup " + ch + " (" + i.to_s + ")\n"
        chnode = node.children[i]
        #      print "debug chnode: " + chnode.to_s + "\n"
        return false if chnode.nil?
        node = chnode
      }
      # check if word may end also
      #   print "word ending: " + node.children[Characters.length].to_s + "\n"
      return false if node.children[String::Characters.length].nil?
      return true
    end
    
    def hitcount(sentence)
      found=0
      wc=0
      missed = []
      hits = []
      sentence.each_word{|word|
        wc = wc + 1
        if contains?(word)
          found = found + 1
          hits << word
        else
          missed << word
        end
      }
      return {:wc => wc, :found => found, :missed => missed, :hits => hits}
    end
    
  end
   
  # Extract words from FinnWordNet index files
  class FinnWordNetIndex
    def filename
      @filename
    end
    
    def initialize(filename)
      @filename = filename
    end
    
    def each_word
      re = Regexp.new('^[' + String::Alphabet + ']')
      File.foreach(filename){|line|
        next unless line.start_with?(re)
        word=line.partition(/ /)[0]
        word.tr('_', ' ')
      }
    end
  end
  
  class Corpus
    
    def filename
      @filename
    end
    
    def initialize(filename)
      @filename = filename
    end
    
    def valid?(sentence)
      return false if sentence.length < 10
      return false unless sentence.match('[' + String::Alphabet + ']+')
      #    return false unless sentence.end_with?(/[.?]/)
      # skip sentences with non-alphabet chars
      return false if sentence.match(Regexp.new('[^' + String::Alphabet + ' ,.?]'))
      return true
    end
    
  end
  
  # http://xml.coverpages.org/TMX-SpecV13.html
  class TMXCorpus < Corpus
    
    def each_sentence
      file = File.new(filename)
      doc = REXML::Document.new file
      doc.root.elements.each("//tuv[@lang='et']"){|tuv|
        sentence=tuv.elements[1].text.downcase
        yield sentence if valid?(sentence)
      }
    end
  end
  
  # CONLL-X format (http://nextens.uvt.nl/~conll/#dataformat) an
  # Fields are separated from each other by a TAB.
  # The 10 fields are:
  # 1) ID: Token counter, starting at 1 for each newsentence.
  # 2) FORM: Word form or punctuation symbol.For the Arabic data only, FORM is a
  # concatenation of the word in Arabic script and its transliteration
  # in Latin script, separated by an underscore.  This rep-resentation is
  # meant to suit both those that do andthose that do not read Arabic.
  # 3)LEMMA: Lemma or stem (depending on the particular treebank) of word
  # form, or an underscoreif not available.  Like for the FORM, the
  # values forArabic are concatenations of two scripts.
  # 4) CPOSTAG: Coarse-grained part-of-speechtag, where the tagset depends on the
  # treebank.
  # 5) POSTAG: Fine-grained part-of-speech tag,where the tagset
  # depends on the treebank. It is iden-tical to the CPOSTAG value if no
  # POSTAG is avail-able from the original treebank.
  # 6) FEATS: Unordered set of syntactic and/ormorphological features (depending on the
  # particu-lar treebank), or an underscore if not available.
  # Setmembers are separated by a vertical bar (|).
  # 7) HEAD: Head of the current token, which iseither a value of ID, or zero (’0’) if the
  # token linksto the virtual root node of the sentence.  Note
  # thatdepending on the original treebank annotation, theremay be
  # multiple tokens with a HEAD value of zero.
  # 8) DEPREL: Dependency relation to the HEAD.The set of dependency relations depends on the
  # par-ticular treebank.  The dependency relation of a to-ken with
  # HEAD=0 may be meaningful or simply’ROOT’ (also depending on the
  # treebank).
  # 9) PHEAD: Projective head of current token,which is either a value of ID or zero (’0’), or an un-derscore if not available.
  # 10)   PDEPREL:   Dependency   relation   to   thePHEAD, or an underscore if not available.
  #
  # cpostags:
  # N, Pron, V, CC, PrfPrc, Adv, A, PrsPrc, Adp, AgPcp, CS, Abbr, Interj
  class CONLLXCorpus < Corpus
    
    def dictionary
      @dictionary
    end
    
    def initialize(filename, dictionary)
      super(filename)
      @dictionary = dictionary
    end
    
    def each_sentence
      sentence = ''
      File.foreach(filename) { |line|
        if line.start_with?("<s>")
          sentence = ''
          next
        end
        
        if line.start_with?("</s>")
          yield(sentence) if valid?(sentence)
          next
        end
        
        v = line.split
        lemma=v[2]
        next if dictionary.contains?(lemma) # skip all non-dictionary words
        
        word=v[1].downcase # get word from input
        sentence << ' ' unless (word == '.' || sentence.empty?)
        sentence << word
      }
    end
    
    def each_token
      File.foreach(filename) {|line|
        if line.start_with?("<s>")
          next
        end
        
        if line.start_with?("</s>")
          next
        end
        
        v=line.split
        yield({:id => v[0], :form => v[1].downcase, :lemma => v[2], :cpostag => v[3], :postag => v[4], :feats => v[5]})
      }
    end
    
  end

  class OneLinerCorpus < Corpus
    def each_sentence
      File.foreach(filename) { |line|
        line = line.downcase
        yield(line)
      }
    end
  end

  class GraphElement
    def initialize(name)
      @name = name
      @weights = {}
    end
    
    def name
      @name
    end

    def total
      weights.values.sum
    end
    
    def weights
      @weights
    end

    def weights=(w)
      @weights = w
    end
    
    def weight(lang)
      weights[lang] || 0.0
    end
    
    def score(lang)
      if weights[lang].nil?
        weights[lang] = 1.0
      else
        weights[lang] = weights[lang] + 1.0
      end
    end
  end

  class Edge < GraphElement
    def to
      @to
    end
    
    def initialize(name, to)
      super(name)
      @to = to
    end

    def to_h
      {:type => :edge, :name => name, :weights => weights, :to => to.name}
    end
  end

  class Node < GraphElement

    def edges
      @edges
    end

    def initialize(name)
      super(name)
      @edges = {}
    end

    def linkname(to)
      name + '-' + to
    end

    def edge(to)
      edges[linkname(to.name)]
    end
    
    def connect(lang, node)
      lname=linkname(node.name)
      e=edges[lname]
      if e.nil?
        e=Edge.new(lname, node)
        edges[lname] = e
      end
      e.score(lang)
      e
    end

    def follow(to)
      e=edges[linkname(to)]
      return nil if e.nil?
      e.to
    end

    def to_h
      {:type => :node, :name=> name, :weights => weights, :edges => edges.values.map{|e| e.name} }
    end
  end

  # Algorithm based on article [1]
  # Evaluation of algorithms, see [2].
  #
  # [1] Tromp, Erik & Pechenizkiy, Mykola. (2011). Graph-Based N-gram Language Identification on Short Texts. Proceedings of Benelearn 2011. 27-34.
  # [2] Panich, Leonid, Stefan Conrad and Martin Mauve. “Comparison of Language Identification Techniques.” (2015).
  class LanguageDetector

    def languages
      @languages
    end
    
    def start_nodes
      @start_nodes
    end

    def nodeindex
      @node_index
    end
    
    def trigramcount
      @trigramcount
    end
    
    def trigramcount=(value)
      @trigramcount = value
    end

    def visits
      @visits
    end

    def visits=(value)
      @visits = value
    end
    
    def transitioncount
      @transitioncount
    end

    def transitioncount=(value)
      @transitioncount=value
    end

    def initialize
      @trigramcount = 0.0
      @transitioncount = 0.0
      @visits = 0.0
      @languages = []
      @start_nodes = {}
      @node_index = {}
      @links = {}
    end

    def train(lang, corpus)
      @languages << lang
      corpus.each_sentence { |s|
        prev = nil
        node = nil
        #      ('_'+s).each_trigram {|trigram|
        s.each_syllable {|trigram|
          @visits = @visits + 1.0
          prev = node
          if prev.nil? # first syllable
            node = start_nodes[trigram]
          else
            node = node.follow(trigram) unless node.nil?
          end
          
          if node.nil?
            # node does not yet exist, append new node
            node = nodeindex[trigram]
            if node.nil?
              node = Node.new(trigram)
              nodeindex[trigram] = node
            end
            node.score(lang)
            @trigramcount = trigramcount + 1.0

            if prev.nil?
              start_nodes[trigram] = node
            else
              prev.connect(lang, node)
              @transitioncount= transitioncount + 1.0
            end
          else
            node.score(lang)
            unless prev.nil?
              prev.connect(lang, node)
              @transitioncount= transitioncount + 1.0
            end
          end
        }
      }
      print "trigrams: " + trigramcount.to_s + " visits: " + visits.to_s + " transitions: " + transitioncount.to_s + "\n"
    end
    
    def confidence(text)
      node = nil
      # link confidences
      lc = languages.inject({}){|h,i| h[i]=0.0; h}
      # node confidence
      nc = languages.inject({}){|h,i| h[i]=0.0; h}
      count = 0.0
      prev = nil
      #    ('_'+text).each_trigram{|trigram|
      text.each_syllable {|trigram|
        count = count + 1.0
        if node.nil? && count < 2.0
          node = nodeindex[trigram]
        else
          prev = node
          node = node.follow(trigram)
        end

        break if node.nil?

        languages.each{|lang|
          nc[lang] = nc[lang] + node.weight(lang)/node.total
          lc[lang] = lc[lang] + prev.edge(node).weight(lang)/prev.edge(node).total unless prev.nil?
        }
      }

      # languages.each{|lang|
      #   print "weights: " + nc[lang].to_s + " " + lc[lang].to_s + "\n"
      # }
      
      languages.inject({}) {|h, lang|
        h[lang]=nc[lang] + lc[lang]
        h
      }
    end

    def save(filename)
      metaout=File.new(filename + ".meta", File::CREAT|File::RDWR,0644)
      metaout << {:languages => languages, :nodecount => trigramcount, :visits => visits, :transitioncount => transitioncount}
      metaout.close

      nodesout=File.new(filename + ".nodes", File::CREAT|File::RDWR,0644)
      edgesout=File.new(filename + ".edges", File::CREAT|File::RDWR,0644)

      
      nodestack = []
      visited = {}
      start_nodes.values.each{|n|
        nodestack.push(n)
        visited[n.name] = true
      }
      while (not nodestack.empty?)
        n = nodestack.shift
        h = n.to_h
        h[:type] = :start unless start_nodes[n.name].nil?
        nodesout << h << "\n"
        n.edges.values.each {|e|
          edgesout << e.to_h << "\n"
          nodestack.push(e.to) unless visited[e.to.name]
          visited[e.to.name] = true
        }
      end
      visited.clear
      nodesout.close
      edgesout.close
    end

    def load(filename)
      File.foreach(filename + ".meta") {|l|
        meta = eval(l)
        print "META: " + meta.to_s + "\n"
        @languages = meta[:languages]
        @trigramcount = meta[:nodecount]
        @visits = meta[:visits]
        @transitioncount = meta[:transitioncount]
      }

      data = []

      File.foreach(filename + ".nodes") {|l|
        data = eval(l)
        n = Node.new(data[:name])
        @trigamcount = @trigramcount + 1.0
        n.weights = data[:weights]
        nodeindex[data[:name]] = n
        start_nodes[data[:name]] = n if data[:type] == :start
      }

      edge_index = {}
      File.foreach(filename + ".edges") {|l|
        data = eval(l)
        n = nodeindex[data[:to]]
        e = Edge.new(data[:name], n)
        @transitioncount = @transitioncount + 1.0
        e.weights = data[:weights]
        edge_index[e.name] = e
      }

      File.foreach(filename + ".nodes") {|l|
        data = eval(l)
        n = nodeindex[data[:name]]
        data[:edges].each {|name|
          e = edge_index[name]
          n.edges[e.name] = e
        }
      }
    end
  end

  class Caesar
    def self.rotate(ch, n)
      finch=String::Characters.index(ch)
      finch.nil? ? ch :  String::Characters[(finch+n) % String::Characters.length].chr
    end
    
    def self.decrypt(msg, key)
      msg.downcase.chars.collect{|ch| rotate(ch, key) }.join
    end

    def self.each_guess(encrypted)
      1.upto(String::Alphabet.length) {|key|
        yield decrypt(encrypted, key)
      }
    end
  end

  class Agent
    include Singleton

    def trie
      @trie
    end
    
    def detector
      @detector
    end

    def minthreshold
      @minthreshold
    end

    def minthreshold=(value)
      @minthreshold=value
    end
    
    def initialize()
      @minthreshold=0.2
    end

    def loadall
      print "Loading dictionary\n"
      @trie = Trie.new
      @trie.load(DictionaryFile)
      
      print "Loading detector\n"
      @detector=LanguageDetector.new
      detector.load('fi-et-detector.model')
    end
    
    def nonsense?(sentence)
      vre = Regexp.new('[' + String::Vowels + ']')
      sentence.each_syllable {|s|
        return true unless s.match(vre) # if syllable is only consonants
      }
      
      sentence.scan(Regexp.new(QuadVowels + "|" + QuadConsonants)).size > 0 # do not allow quad consonants or quad vowels
    end

    def bestconfidence(confidences)
      best=0.0
      confidences.each_value{|v|
        best = v if best < v
      }
      best
    end
    
    def challenge(encrypted)
      maybefinnish=[]
      bestconfidences=nil
      best=0.0
      found=0
      wc=0
      Caesar.each_guess(encrypted) { |decrypted|
        print "DEBUG: " + decrypted + "\n"

        hc = trie.hitcount(decrypted)
        print "dictionary check: " + hc.to_s + "\n"

        if hc[:found] == 0
          print "dropped sentence, no finnish words found: '" + decrypted + "'\n"
          next
        end

        # make brutal check before accepting
        if nonsense?(decrypted)
          print "dropped candidate due brutal check: '" + decrypted + "'\n"
          next
        end

        confidences=detector.confidence(decrypted)
        print "confidence: " + confidences['fi'].to_s + "\n"

        if( confidences['fi'] < confidences['et'] )
          print "more likely estonian: '" + decrypted + "'\n"
          next
        end

        if confidences['fi'] < minthreshold
          print "probably not finnish: '" + decrypted + "'\n"
          if hc[:found].to_f/hc[:wc].to_f > 0.5
            print "wierd, high finnish word count while detected as non-finnish\n"
            hitsconfidence=detector.confidence(hc[:hits].join(' '))
            print "hits confidence: " + hitsconfidence.to_s + "\n"        
          end
          next
        end
        
        highest=bestconfidence(confidences)
        if bestconfidences.nil? || best < highest
          # found better candidate
          bestconfidences = confidences
          best = highest
        end

        if confidences['fi'] < best
          print "probably worse hit than current best: '" + decrypted + "'\n"
          next
        end

        if hc[:found] < 3
          print "dropped candidate after dictionary lookup: "
          print hc.to_s + " confidence: " + confidences['fi'].to_s
          print "'" + decrypted + "'\n"
          next
        end

        mc=detector.confidence(hc[:missed].join(' '))
        if hc[:found] != hc[:wc] && confidences['fi'] < 1.0 && mc['fi'] < minthreshold
          print "dropped candidate after dictionary lookup: "
          print hc.to_s + " confidence on missed: " + mc['fi'].to_s
          print " confidence on sentence: " + confidences['fi'].to_s
          print " '" + decrypted + "'\n"            
        else
          maybefinnish<< {:sentence => decrypted, :confidence => confidences['fi'], :wc => hc[:wc], :found => hc[:found] }
        end
      }
      if maybefinnish.length > 0
        { :finnish => true, :sentence => maybefinnish.last }
      else
        { :finnish => false, :sentence => encrypted }
      end
    end

    def fetch_encrypted
      response=RestClient.get 'https://koodihaaste-api.solidabis.com/secret'
      secret = JSON.parse(response.body)
      token=secret["jwtToken"]
      url=secret["bullshitUrl"]
      response = RestClient.get url, {:Authorization => 'Bearer ' + token}
      JSON.parse(response.body)
    end
    
    def run
      #print "Run spy\n"
      data=fetch_encrypted
      bullshits=[]
      finnish=[]
      data['bullshits'].each {|m|
        discovery=challenge(m['message'])
        if discovery[:finnish]
          finnish << discovery[:sentence]
        else
          bullshits << discovery[:sentence]
        end
      }
      [finnish, bullshits]
      #total = bullshits.length + finnish.length
      #hits = {}
      #TruePositive.each {|s| hits[s]=0 }
      
      #print "Finnish sentences (" + finnish.length.to_s + "/" + total.to_s + "):\n"
      #finnish.each {|s|
        # if hits[s[:sentence]]
        #   hits[s[:sentence]] = 1 # true positive
        # else
        #   hits[s[:sentence]] = -1 # false positive
        # end
        
      #  print s
      #  print "\n"
      #}

      # print "Bullshit sentences (" + bullshits.length.to_s + "/" + total.to_s + "):\n"
      # bullshits.each {|s|
      #   print s + "\n"
      # }

      # print "True positive: " + hits.values.select{|v| v > 0}.length.to_s + "\n"
      # print "False positive: " + hits.values.select{|v| v < 0}.length.to_s + "\n"
      # print "False negative: " + hits.values.select{|v| v == 0}.length.to_s + "\n"
      # print "True negative: " + (bullshits.length - hits.values.select{|v| v == 0}.length).to_s + "\n"
      # print "False positive sentences:\n"
      # hits.each_pair{|k,v| print k.to_s + "\n" if v < 0}
      # print "False negative sentences:\n"
      # hits.each_pair{|k,v| print k.to_s + "\n" if v == 0}
    end

    def build_model(ficorpuspath, etcorpuspath)
      detector=LanguageDetector.new
      detector.train('fi', OneLinerCorpus.new(ficorpuspath))
      detector.train('et', OneLinerCorpus.new(etcorpuspath))
      detector.train('fi', OneLinerCorpus.new(DictionaryFile))
      detector.save('fi-et-detector.model')
    end
    
    def build_dictionary(fwnpath, ftbpath) 
      trie = Trie.new
      index=FinnWordNetIndex.new(fwnpath + '/dict/index.adj')
      index.each_word{|word|
        trie.insert(word)
      }
      FinnWordNetIndex.new(fwnpath + '/dict/index.adv')
      index.each_word{|word|
        trie.insert(word)
      }
      FinnWordNetIndex.new(fwnpath + '/dict/index.noun')
      index.each_word{|word|
        trie.insert(word)
      }
      FinnWordNetIndex.new(fwnpath + '/dict/index.verb')
      index.each_word{|word|
        trie.insert(word)
      }
    
      corpus=CONLLXCorpus.new(ftbpath, trie)
      corpus.each_token {|t|
        
        if ["Num", "Punct", "Interj", "Abbr"].include?(t[:cpostag]) || t[:head] == 'Abbr'
          next
        end
        
        trie.insert(t[:form])
        trie.insert(t[:lemma])
      }
      
      trie.save(DictionaryFile)
    end
  end
end
