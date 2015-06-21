require 'nokogiri'
require 'open-uri'

MARK_FILE = "mark.dat"

def wait_for_threads(threads)
  print "Waiting for downloads to finish..."
  threads.each { |t| t.join }
  puts " ok"
end

def quit(num, threads)
  if threads.any?
    wait_for_threads(threads)
  end
  File.open(MARK_FILE, 'w') { |f| f.write(num - 1) }
  exit
end

#EXCLUDE = %w(ActionScript flash flex xslt metro active_directory PostgreSQL autodesk ibm bible wpf ejb vmware j2me Java visual_studio c# f# Erlang Clojure Windows awk css html html5 php mysql jsp head_first sql oracle wordpress mercurial moodle iOS flex flash cisco drupal joomla ajax jquery javascript linq linux iphone access rails ruby perl python adobe javafx scala cocoa objective-c BlackBerry opengl netbeans dummies agile blender biztalk mac embedded jvm android mongo mongodb solr dojo asp.net sharepoint microsoft ipad asterisk voip silverlight uml vim emacs R jira redis node xaml cms sams jdk roo jruby xcode powershell solidworks mootools blend dart node.js angular.js couchdb coffeescript virtualization dreamweaver spring excel access puppet enterprise ipv6 entity cassandra sap sip office apache grails visual_basic visual_studio xml .net hadoop quickbooks lotus gradle jboss openstack xna phonegap unity game)

EXCLUDE = %w(ActionScript flash flex xslt metro active_directory PostgreSQL autodesk ibm bible wpf ejb vmware j2me Java visual_studio c# f# Erlang Clojure Windows awk css php mysql jsp head_first sql oracle wordpress mercurial moodle iOS flex flash cisco drupal joomla ajax linq iphone access perl adobe javafx cocoa objective-c BlackBerry opengl netbeans dummies agile blender biztalk embedded jvm android solr dojo asp.net sharepoint microsoft ipad asterisk voip silverlight uml vim emacs R jira xaml cms sams jdk roo xcode powershell solidworks mootools blend dart couchdb virtualization dreamweaver spring excel access puppet enterprise ipv6 entity cassandra sap sip office apache grails visual_basic visual_studio xml .net hadoop quickbooks lotus gradle jboss openstack xna phonegap unity game)

def exclude?(book)
  for word in EXCLUDE
    return true if book[:title].gsub('#', 'AAA') =~ /\b#{word.gsub('#', 'AAA').gsub('_', ' ')}\b/i
  end
  false
end

if ARGV.first == 'help'
  puts "Get all new books:              ruby it-ebooks.rb"
  puts "Get n books from last download: ruby it-ebooks.rb 100"
  puts "Options: y - download, ENTER - next, d - description, q - quit"
  puts "(CTRL+C also works for quitting but the current position in not remembered)"
  exit
end

puts "Working..."

mark = File.exists?(MARK_FILE) ? File.read(MARK_FILE).to_i : 0
max_num = Nokogiri::HTML(open('http://it-ebooks.info/')).css('a').select { |a| a['href'] =~ /\/book\// }.map { |a| a[:href].match(/book\/(\d+)/)[1].to_i }.max

latest = ARGV.first ? [mark + ARGV.first.to_i, max_num].min : max_num

books = []
nothing_to_do = true
for num in (mark + 1).upto(latest)
  nothing_to_do = false
  page = open("http://it-ebooks.info/book/#{num}/")
  if page.base_uri.path == "/404/"
    puts "#{num} - Not Found"
  else
    doc = Nokogiri::HTML(page)
    div = doc.css("div[itemtype='http://schema.org/Book']")

    book = {}
    book[:num] = num
    book[:title] = div.css("h1").text
    book[:subtitle] = div.css("h3").text
    book[:publisher] = doc.css("a[itemprop='publisher']").text
    book[:description] = doc.css("span[itemprop='description']").text
    book[:year] = doc.css("b[itemprop='datePublished']").text
    #book[:link] = "http://it-ebooks.info#{doc.css('a#dl').first['href']}"

    if exclude?(book)
      puts "Excluding #{num}: #{book[:title]} (#{book[:year]})"
    else
      puts "#{num} (#{num - mark}/#{latest - mark})"
      books << book
    end
  end
end

puts
threads = []

books.each_with_index do |book, index|
  puts "#{book[:num]} (#{index + 1}/#{books.count})"
  puts book[:title]
  puts book[:subtitle] unless book[:subtitle].empty?
  puts "#{book[:publisher]}, #{book[:year]}"

  input = STDIN.gets.chomp.downcase

  quit(book[:num], threads) if input == "q"

  if input == "d"
    puts book[:description]
    input = STDIN.gets.chomp.downcase
    quit(book[:num], threads) if input == "q"
  end

  if input == "y"
    threads << Thread.new do
      begin
        f = open(book[:link])
        cd = f.meta['content-disposition']

        if cd.nil? # content-disposition was missing, try again
          f = open(book[:link])
          cd = f.meta['content-disposition']
        end

        filename = cd.match(/filename=(\"?)(.+)\1/)[2]

        if File.exists?(filename)
          puts "#{filename} already exists!"
        else
          File.open(filename, "wb") do |file|
            file.write f.read
          end
        end
      rescue => e
        puts
        puts "### Error downloading book #{book[:num]}: #{e.message} ###"
      end
    end
    puts
  end
end

if threads.any?
  wait_for_threads(threads)
elsif nothing_to_do
  puts "No new books."
end

File.open(MARK_FILE, 'w') { |f| f.write(latest) }
