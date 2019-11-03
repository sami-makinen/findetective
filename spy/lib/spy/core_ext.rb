# coding: utf-8
class String

  Alphabet="abcdefghijklmnopqrstuvwxyzåäö"
  Characters=Alphabet.chars
  Vowels="aeiouyåäö"
  Consonants="bcdfghjklmnpqrstvwxz"
  Diphtongs="ai ei oi äi öi ey äy öy au eu ou ui yi iu iy ie uo yö"
  Punctuation='.,?!:;_-'
  
  def word_count
    self.split(' ').length
  end
  
  def each_word
    stripped = tr(Punctuation, ' ')    
    stripped.split(' ').each {|word|
      next if word.empty?
      yield(word)
    }
  end
  
  def each_syllable
    
    c = Consonants.chars
    v = Vowels.chars
    d = Diphtongs.split(' ')
    
    stripped = tr(Punctuation, ' ')
    stripped.each_word { |word|
      if(word.length <= 2)
        yield(word)
        next
      end
      #      print "debug: each_syllable: word = " + word + "\n"
      syllables = []
      r = word.reverse
      syllable = ''
      cur = :none
      0.upto(r.length-1) {|pos|
        # if last is a or ä and next is different vowel, then a or ä is syllable
        if ['a', 'ä'].include?(r[pos]) && r[pos] != r[pos+1] && v.include?(r[pos+1])
          syllable = r[pos] + syllable
          #          print "debug: a or ä syllable = " + syllable + " pos = " + r[pos] + " cur: " + cur.to_s + "\n"
          syllables.push(syllable)
          syllable = ''
          cur = :none
          next
        end
        
        if cur == :none
          if v.include?(r[pos]) # if last is vowel, track back till consonant or diphtong
            cur=:vowel
          else # if c.include?(last)  # if last is consonant, track back
            cur=:consonant
          end
          syllable = r[pos] + syllable
          #          print "debug: syllable = " + syllable + " pos = " + r[pos] + " cur: " + cur.to_s + "\n"
          next
        end
        
        if cur == :vowel
          if v.include?(r[pos])
            if r[pos] == syllable[0] || d.include?(r[pos] + syllable ) # doubel vowel or diphtong
              syllable = r[pos] + syllable
            #              print "debug: syllable = " + syllable + " pos = " + r[pos] + " cur: " + cur.to_s + "\n"                                
            else
              # vowels do not form diphtong
              syllables.push(syllable)
              cur = :vowel
              syllable = r[pos]
              #              print "debug: syllable = " + syllable + " pos = " + r[pos] + " cur: " + cur.to_s + "\n"              
              next
            end
          else # found consonant
            syllable = r[pos] + syllable
            #            print "debug: syllable = " + syllable + " pos = " + r[pos] + " cur: " + cur.to_s + "\n"            
            syllables.push(syllable)
            syllable = ''
            cur = :none
            next
          end
        else # cur == :consonant
          if v.include?(r[pos])
            syllable = r[pos] + syllable
          #            print "debug: syllable = " + syllable + " pos = " + r[pos] + " cur: " + cur.to_s + "\n"            
          else
            if c.include?(syllable) # two consonants probably syllable continues over vowels 
              syllable = r[pos] + syllable
            #              print "debug: syllable = " + syllable + " pos = " + r[pos] + " cur: " + cur.to_s + "\n"            
            else
              syllable = r[pos] + syllable
              #              print "debug: syllable = " + syllable + " pos = " + r[pos] + " cur: " + cur.to_s + "\n"                        
              syllables.push(syllable)
              syllable = ''
              cur = :none
            end
          end
        end
      }
      syllables.push(syllable)
      while not syllables.empty?
        s=syllables.pop
        next if s.nil? || s.empty?
        #        print "yielding: " + s + "\n"
        yield(s)
      end
    }
  end
  
  def each_trigram
    if(self.length < 3)
      yield(self)
    end
    
    2.upto(self.length-1) {|i|
      a=self[i-2]
      b=self[i-1]
      c=self[i]
      yield(a+b+c)
    }
  end
  
  def syllables
    arr = []
    each_syllable{|s| arr << s}
    arr
  end
  
  def hyphenate
    split(' ').map {|word|
      word.syllables.join('-')
    }.join(' ')
  end
end
