namespace :spy do
  desc "Build dictionary file from given sources [path to unzipped FinnWordNet-2.0, path untarred FinnishTreeBank 3.0]."
  task :builddict, [:fwnpath] do |task, args|
    trie = Spy::Trie.new
    index=Spy::FinnWordNetIndex.new(args.fwnpath + '/dict/index.adj')

    index.each_word{|word|
      trie.insert(word)
    }
    index=Spy::FinnWordNetIndex.new(args.fwnpath + '/dict/index.adv')
    index.each_word{|word|
      trie.insert(word)
    }
    index=Spy::FinnWordNetIndex.new(args.fwnpath + '/dict/index.noun')
    index.each_word{|word|
      trie.insert(word)
    }
    index=Spy::FinnWordNetIndex.new(args.fwnpath + '/dict/index.verb')
    index.each_word{|word|
      trie.insert(word)
    }
    
    # corpus=Spy::CONLLXCorpus.new(args.ftbpath, trie)
    # corpus.each_token {|t|
      
    #   if ["Num", "Punct", "Interj", "Abbr"].include?(t[:cpostag]) || t[:head] == 'Abbr'
    #     next
    #   end

    #   if t[:form].nonsense?
    #     print "skip: " + t[:form] + "\n"
    #     next
    #   end
      
    #   trie.insert(t[:form])
    #   trie.insert(t[:lemma])
    # }

    trie.save(Spy::DictionaryFile)
  end
  
  desc "Build language detector model."
  task :buildmodel, [:ficorpuspath] do |task, args|
    detector=Spy::LanguageDetector.new
    detector.train('fi', Spy::OneLinerCorpus.new(args.ficorpuspath))
    #detector.train('et', OneLinerCorpus.new(etcorpuspath))
    detector.train('fi', Spy::OneLinerCorpus.new(Spy::DictionaryFile))
    detector.save(Spy::DetectorModelName)
  end
end
