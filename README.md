# it-ebooks.info downloader

## Easy downloading of it-ebooks from command line

Examine and get all new books: `./it-ebooks.rb`

Examine and get `100` next books since last download: `./it-ebooks.rb 100`

**y**: download to `books` subfolder, **d**: see description, **enter**: skip, **q**: quit

If you want to start at some particular book number, just edit `mark.dat`

## Exclude books with specific keywords

`cp exclude.txt.sample exclude.txt` and edit according to your preferences

## Todo

[it-ebooks](http://it-ebooks.info) actually has an api so if this HTML scraping code breaks, I will make it use the api
