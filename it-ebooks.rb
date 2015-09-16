#!/usr/bin/env ruby
require 'nokogiri'
require 'open-uri'
require 'fileutils'
require 'colorize'

MARK_FILE = "mark.dat"
SITE = "http://it-ebooks.info"

def wait_for_threads(threads)
  print "Waiting for downloads to finish..."
  threads.each { |t| t.join }
  puts " ok"
end

def quit(num, threads)
  wait_for_threads(threads) if threads.any?
  File.open(MARK_FILE, 'w') { |f| f.write(num - 1) }
  exit
end

def exclude?(book)
  file = 'exclude.txt'
  if File.exists?(file)
    for word in File.read(file).chomp.split
      return true if book[:title].gsub('#', 'AAA') =~ /\b#{word.gsub('#', 'AAA').gsub('_', ' ')}\b/i
    end
  end
  false
end

def prompt(options = {})
  desc = options[:description] ? '/ Desciption (d)' : ''
  print "\nDownload (y) / Skip (enter) #{desc} / Quit (q): ".squeeze
  input = STDIN.gets.chomp.downcase
  puts
  input
end

if ARGV.first == 'help'
  puts "Get all new books:              ruby it-ebooks.rb"
  puts "Get n books from last download: ruby it-ebooks.rb 100"
  puts "Options: y - download, ENTER - next, d - description, q - quit"
  puts "(CTRL+C also works for quitting but the current position in not remembered)"
  exit
end

mark = File.exists?(MARK_FILE) ? File.read(MARK_FILE).to_i : 0
max_num = Nokogiri::HTML(open(SITE)).css('a').select { |a| a['href'] =~ /\/book\// }.map { |a| a[:href].match(/book\/(\d+)/)[1].to_i }.max

latest = ARGV.first ? [mark + ARGV.first.to_i, max_num].min : max_num

books = []
nothing_to_do = true
for num in (mark + 1).upto(latest)
  nothing_to_do = false
  page = open("#{SITE}/book/#{num}/")
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
    book[:link] = doc.css("a").find { |link| link['href'] =~ /filepi\.com/ }['href']

    repost = doc.css("div[itemtype='http://schema.org/Book']").text.include?('repost')

    if exclude?(book)
      print "Excluding #{num}: "
      puts "#{book[:title]} (#{book[:year]})".cyan
    elsif repost
      print "Excluding #{num} (repost): "
      puts "#{book[:title]} (#{book[:year]})".red
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
  puts book[:title].cyan
  puts book[:subtitle] unless book[:subtitle].empty?
  puts "#{book[:publisher]}, #{book[:year]}"
  input = prompt(description: true)

  quit(book[:num], threads) if input == "q"

  if input == "d"
    puts book[:description]
    input = prompt
    quit(book[:num], threads) if input == "q"
  end

  if input == "y"
    threads << Thread.new do
      begin
        f = open(book[:link], "Referer" => SITE)

        cd = f.meta['content-disposition']

        unless cd # content-disposition was missing, try again
          f = open(book[:link], "Referer" => SITE)
          cd = f.meta['content-disposition']
        end

        base = 'books'
        FileUtils.mkdir_p base
        filepath = File.join(base, cd.match(/filename=(\"?)(.+)\1/)[2])

        if File.exists?(filepath)
          puts "#{filepath} already exists!"
        else
          File.open(filepath, "wb") do |file|
            file.write f.read
          end
        end
      rescue => e
        puts
        puts "### Error downloading book #{book[:num]}: #{e.message}"
        puts e.backtrace
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
