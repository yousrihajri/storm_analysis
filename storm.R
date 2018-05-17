# For Markdown
###---
###title: "U.S. National Oceanic and Atmospheric Administration's (NOAA) storm database"
###output: html_document :
###            keep_md: true
###---
###```{r}
###knitr::opts_chunk$set(fig.width=12, fig.height=12) ###to sizing plots
###knitr::opts_chunk$set(echo = TRUE) ###To keep code, FALSE if no code in output
###```
###SYNOPSIS
###"storm" is a data frame extract from NOAA Storm Database, recording information about various types
###of storms that happened on the US soil from 1950 to 2011. In the earlier years of the database
###there are generally fewer events recorded, most likely due to a lack of good records.
###Our aim is to get measurements that enable decision making on resource allocations.
###We will show which types of storms are more damaging than others on human health and on economy.
###Document summary :
###-LIBRARIES & SETUP
###-GETTING THE DATA
###-UNIVARIATE DATA EXPLORATION
###-DATA PROCESSING
###-RESULTS



# LIBRARIES & SETUP

suppressWarnings(suppressMessages(suppressPackageStartupMessages(library(tidyverse))))
suppressWarnings(suppressMessages(suppressPackageStartupMessages(library(magrittr))))
suppressWarnings(suppressMessages(suppressPackageStartupMessages(library(Hmisc))))
suppressWarnings(suppressMessages(suppressPackageStartupMessages(library(funModeling))))
suppressWarnings(suppressMessages(suppressPackageStartupMessages(library(DataExplorer))))
suppressWarnings(suppressMessages(suppressPackageStartupMessages(library(data.table))))
suppressWarnings(suppressMessages(suppressPackageStartupMessages(library(reshape))))
suppressWarnings(suppressMessages(suppressPackageStartupMessages(library(reshape2))))
suppressWarnings(suppressMessages(suppressPackageStartupMessages(library(gridExtra))))
suppressWarnings(suppressMessages(suppressPackageStartupMessages(library(mice))))
suppressWarnings(suppressMessages(suppressPackageStartupMessages(library(knitr))))
suppressWarnings(suppressMessages(suppressPackageStartupMessages(library(kableExtra))))
suppressWarnings(suppressMessages(suppressPackageStartupMessages(library(icon))))
suppressWarnings(suppressMessages(suppressPackageStartupMessages(library(ggthemes))))

fa_r_project(colour = "#384CB7", size=30)
sessionInfo()


options(scipen = 999, digits = 0)
setwd(dir = "C:\\Users\\yousri.hajri\\Documents\\DATA_SCIENCE\\5_REPRODUCIBLE_RESEARCH\\WEEK4")

### Creating FUNCTION_KABLE (for formatting tables on markdown)

FUNCTION_KABLE <- function (TABLE) {
    X <- deparse(substitute(TABLE))
    kable (TABLE, format = "html", row.names = T) %>% 
        kable_styling(bootstrap_options = c("striped", "hover", "condensed", "responsive"),
                      full_width = F, position = "center", font_size=10) %>%
        add_footnote (notation = "symbol", c(paste("TABLE:  ", X))) %>%
        column_spec(column=1, bold = T, border_left = T) %>%
        column_spec(column=2, width = "3cm")
    
}




# GETTING THE DATA

storm <- readRDS("storm") ### If you saved once
file = "https://d396qusza40orc.cloudfront.net/repdata%2Fdata%2FStormData.csv.bz2"
if (is.null(storm)) download.file(file, destfile = "storm.zip")
if (is.null(storm))   storm <- read.csv("storm.zip")
if (is.null(storm)) saveRDS(object = storm, file = "storm") ### Remove the condition & use it once

### DATA TRANSFORMATION FOR EDA
storm %<>% mutate_if(is.factor, as.character) %>% as.data.table()
###Preliminary transformation of factors to character and of dataframe to datatable

# EDA UNIVARIATE

##Overall exploration of the data
names (storm) ###PlotStr(storm, type="diagonal")
summary(storm)
str(storm)
object.size(storm)
FUNCTION_KABLE (df_status(storm))
apply(is.na(storm),2,sum) ###PlotMissing(storm)
describe(storm[,c("FATALITIES","INJURIES","PROPDMG","CROPDMG")])
###Only character variables exploration
###freq <- freq(storm[,c("EVTYPE","STATE","PROPDMGEXP","CROPDMGEXP")], path_out="freq_plots", plot=FALSE)
###BarDiscrete(storm)
###Only numerical variables exploration
###plot <- plot_num(storm, bins=30); plot 
FUNCTION_KABLE(profiling_num(storm)) ### More details for numerical


# DATA PROCESSING

##Choosing the best variables to answer the question

storm <- select (storm, STATE,BGN_DATE,EVTYPE,FATALITIES,INJURIES,PROPDMG,CROPDMG)
SetNaTo(storm, list(0L, "unknown")) ###Set NA's to 0 if numerical & to "unknown" if character / no effect
FUNCTION_KABLE(head(storm,15))

##Character variables

###Var: EVTYPE cleaning (to minimize OTHER)
storm$EVTYPE %<>% toupper() %>%
    gsub(pattern = "TSTM", replacement = "THUNDERSTORM") %>%
    gsub(pattern = "WINDS", replacement = "WIND") %>%
    gsub(pattern = "/MIX", replacement = "") %>%
    gsub(pattern = "URBAN/SML STREAM FLD", replacement = "FLOOD") %>%
    gsub(pattern = "/HAIL", replacement = "") %>%
    gsub(pattern = "WILD/FOREST FIRE", replacement = "WILDFIRE") %>%
    gsub(pattern = "FLOODING", replacement = "FLOOD")
storm$EVTYPE <- ifelse(storm$EVTYPE %in% freq(storm, "EVTYPE", plot=F)[1:20,]$EVTYPE, 
                           storm$EVTYPE,
                           "OTHER")
storm$EVTYPE %<>% as.factor()
FUNCTION_KABLE(freq(storm, "EVTYPE", plot = FALSE))

###Var: BGN_DATE transformation into YEAR
storm$BGN_DATE %<>% as.Date.character(format = "%m/%d/%Y %H:%M:%S")
storm$BGN_DATE <- cut(storm$BGN_DATE, breaks="year") %>% year() %>% as.integer()
storm <- dplyr::rename(storm, YEAR=BGN_DATE)
FUNCTION_KABLE(head(storm,15))

### Reducing years for incomplete data
options(scipen = 999, digits = 3)
storm_year <- aggregate(.~YEAR, data = select(storm, YEAR,FATALITIES,INJURIES,PROPDMG,CROPDMG), sum)
storm_year_scaled <- select(storm_year, -YEAR) %>% scale(center = FALSE) %>% as.matrix()
heatmap(storm_year_scaled, Rowv = NA, Colv = NA, revC = T, margins = c(10,2))

###We remark from the pattern of the data that from 1994 data has changed
###We will work only with the newest data (starting from 1994)
###More analysis can be done at this point but we will assume that old data is useless at this point
storm_year %<>% filter(YEAR>1993)
FUNCTION_KABLE(head(storm,15))

###Plotting the evolution of damage along the years
storm_year_human <- melt(storm_year, id=c("YEAR")) %>% filter(variable %in% c("FATALITIES","INJURIES"))
plot_human <- ggplot(data = storm_year_human, aes(x = YEAR, y = value)) +
    geom_point() + geom_smooth(method = 'loess') +
    facet_wrap(~variable) +
    theme_economist() +
    labs(title = "EVOLUTION OF HUMAN IMPACT THROUGH YEARS") +
    theme(legend.position = "bottom",
          legend.direction = "horizontal",
          legend.title = element_blank())
storm_year_economic <- melt(storm_year, id=c("YEAR")) %>% filter(variable %in% c("PROPDMG","CROPDMG"))
plot_eco <- ggplot(data = storm_year_economic, aes(x = YEAR, y = value)) +
    geom_point() + geom_smooth(method = 'loess') +
    facet_wrap(~variable) +
    theme_economist() +
    labs(title = "EVOLUTION OF ECONOMIC IMPACT THROUGH YEARS") +
    theme(legend.position = "bottom",
          legend.direction = "horizontal",
          legend.title = element_blank())
###grid
grid.arrange (plot_human, plot_eco, nrow=2)

# RESULTS
## Analysing by EVTYPE from 1994

###Human Analysis Data Prep
storm %<>% filter(YEAR>1993)
storm_evtype_fat <- aggregate(FATALITIES~EVTYPE, storm, sum)
storm_evtype_inj <- aggregate(INJURIES~EVTYPE, storm, sum)
storm_evtype_human <- merge(storm_evtype_fat, storm_evtype_inj, by="EVTYPE")
storm_evtype_human$sum <- apply (storm_evtype_human[,c(2:3)], 1, sum)
storm_evtype_human <- dplyr::rename(storm_evtype_human, SUM_HUMAN=sum)
storm_evtype_human <- melt(data = storm_evtype_human, id=c("EVTYPE"))
storm_evtype_human$mean_year_value <- storm_evtype_human$value/18
plot_human <- ggplot(data = storm_evtype_human, aes(x = EVTYPE, y = mean_year_value)) +
    geom_col() + coord_flip() +
    facet_wrap(~variable) +
    theme_economist() +
    labs(title = "YEARLY_MEAN IMPACT ON HUMANS BY STORM TYPE") +
    theme(legend.position = "bottom",
          legend.direction = "horizontal",
          legend.title = element_blank())
###Economic Analysis Data Prep
storm_evtype_prop <- aggregate(PROPDMG~EVTYPE, storm, sum)
storm_evtype_crop <- aggregate(CROPDMG~EVTYPE, storm, sum)
storm_evtype_eco <- merge(storm_evtype_prop, storm_evtype_crop, by="EVTYPE")
storm_evtype_eco$sum <- apply (storm_evtype_eco[,c(2:3)], 1, sum)
storm_evtype_eco <- dplyr::rename(storm_evtype_eco, SUM_ECO=sum)
storm_evtype_eco <- melt(data = storm_evtype_eco, id=c("EVTYPE"))
storm_evtype_eco$mean_year_value <- storm_evtype_eco$value/18
plot_eco <- ggplot(data = storm_evtype_eco, aes(x = EVTYPE, y = mean_year_value)) +
    geom_col() + coord_flip() +
    facet_wrap(~variable) +
    theme_economist() +
    labs(title = "YEARLY_MEAN IMPACT ON ECONOMY BY STORM TYPE") +
    theme(legend.position = "bottom",
          legend.direction = "horizontal",
          legend.title = element_blank())
###grid
grid.arrange (plot_human, plot_eco, nrow=2)




