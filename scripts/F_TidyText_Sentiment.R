#' Title: Intro: TidyText Sentiment
#' Purpose: Sentiment nonsense
#' Author: Ted Kwartler
#' Date: Apr 10, 2023
#'

# Libs
library(tidytext)
library(dplyr)
library(tm)
library(radarchart)
library(textdata)
library(ggplot2)
library(tidyr)

# Custom Functions
tryTolower <- function(x){
  y = NA
  try_error = tryCatch(tolower(x), error = function(e) e)
  if (!inherits(try_error, 'error'))
    y = tolower(x)
  return(y)
}

cleanCorpus<-function(corpus, customStopwords){
  corpus <- tm_map(corpus, removePunctuation)
  corpus <- tm_map(corpus, stripWhitespace)
  corpus <- tm_map(corpus, removeNumbers)
  corpus <- tm_map(corpus, content_transformer(tryTolower))
  corpus <- tm_map(corpus, removeWords, customStopwords)
  return(corpus)
}

# Create custom stop words
customStopwords <- c(stopwords('english'))

# Read in multiple files as individuals
txtFiles<-c('https://raw.githubusercontent.com/kwartler/HBS_NLP_guest_lecture/main/data/starboy.txt',
            'https://raw.githubusercontent.com/kwartler/HBS_NLP_guest_lecture/main/data/in_your_eyes.txt',
            'https://raw.githubusercontent.com/kwartler/HBS_NLP_guest_lecture/main/data/pharrell_williams_happy.txt') 
documentTopics <- c("starboy", "eyes", "happy") 

# Read in as a list
all <- lapply(txtFiles,readLines)

# This could be made more concise but we're going to do it within a loop
cleanTibbles <- list()
for(i in 1:length(all)){
  x <- VCorpus(VectorSource(all[i])) #declare as a corpus
  x <- cleanCorpus(x, customStopwords) #clean each corpus
  x <- DocumentTermMatrix(x) #make a DTM
  x <- tidy(x) #change orientation
  x$document <- documentTopics[i]
  cleanTibbles[[documentTopics[i]]] <- x #put it into the list
}

# Examine
cleanTibbles$eyes
dim(cleanTibbles$eyes)

# Organize into a single tibble
allText <- do.call(rbind, cleanTibbles)

# Get bing lexicon
# "afinn", "bing", "nrc", "loughran"
bing <- get_sentiments(lexicon = c("bing"))
bing

# Perform Inner Join
bingSent <- inner_join(allText,
                       bing, 
                       by=c('term'='word'))
bingSent

# Quick Analysis - count of words
bingResults <- aggregate(count~document+sentiment, bingSent, sum)
pivot_wider(bingResults, names_from = document, values_from = count)

# Get afinn lexicon
afinn <- get_sentiments(lexicon = c("afinn")) 
afinn

# Word Sequence
allText$idx       <- as.numeric(ave(allText$document, 
                                     allText$document, FUN=seq_along))
# Perform Inner Join
afinnSent <- inner_join(allText,
                        afinn, 
                        by=c('term'='word'))
afinnSent

# Calc
afinnSent$ValueCount <- afinnSent$value * afinnSent$count 
afinnSent

# If you did have a timestamp you can easily make a timeline of sentiment using this code
# The idx here is not temporal but this is an example if you were tracking over time instead of alpha
plotDF <- subset(afinnSent, afinnSent$document=='eyes')
ggplot(plotDF, aes(x=idx, y=ValueCount, group=document, color=document)) +
  geom_line()

# Get nrc lexicon,notice that some words can have multiple sentiments
# You may be prompted to download this the first time running the code
nrc <- lexicon_nrc()

# Perform Inner Join
nrcSent <- inner_join(allText,
                      nrc, 
                      by = c('term' = 'word'),
                      multiple = "all")
nrcSent

# Drop pos/neg leaving only emotion
nrcSent <- nrcSent[-grep('positive|negative',nrcSent$sentiment),]

# Manipulate for radarchart
nrcSentRadar <- as.matrix(table(nrcSent$sentiment, nrcSent$document))
nrcSentRadar

# Normalize for length; prop.table by column is "2"
nrcSentRadar <- prop.table(nrcSentRadar,2)
nrcSentRadar
colSums(nrcSentRadar) #quick check to see what prop table did

pivot_longer(as.data.frame.matrix(nrcSentRadar), col = everything())

# Organize
plotDF <- data.frame(labels = rownames(nrcSentRadar),
                           as.data.frame.matrix(nrcSentRadar),
                           row.names = NULL)
plotDF

# Chart
chartJSRadar(scores = plotDF, labelSize = 10, showLegend = T)
# End