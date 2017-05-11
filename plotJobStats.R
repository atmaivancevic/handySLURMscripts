#!/usr/bin/env Rscript

# R script to make a simple scatter plot of job stats
# Example usage:
# Rscript --vanilla plotJobStats.R BWA_highmem_jobs_nr.txt BWA_highmem_jobs.pdf

args = commandArgs(trailingOnly=TRUE)
# args[1] = input file name
# args[2] = output file name

# test if there is at least one argument: if not, return an error
if (length(args)==0) {
  stop("At least one argument must be supplied (input file).n", call.=FALSE)
} else if (length(args)==1) {
  # default output file
  args[2] = "all"
}

setwd("/fast/users/a1211880/jobStats/")
pdf(file = args[2])
data <- read.table(args[1], sep ="\t", header = T)
title <- gsub(pattern = "_nr.txt",replacement = "", x = args[1])
pdata <- plot(x = data$ElapsedTimeHr, y = data$MemUsedGB, main = title, xlab="Elapsed Time (hr)", ylab="Memory Used (gb)", xlim = range(pretty(c(0,max(data$ElapsedTimeHr)))), ylim = range(pretty(c(0,max(data$MemUsedGB)))))
dev.off()

q(save="yes")



### Alternative way of doing it

#setwd("/fast/users/a1211880/")
#files <- list.files(path = "jobStats/")

#pdf(file = "slurmPlots.pdf", onefile = TRUE)
#for(i in 1:length(files)){
#  print(i)
#  data <- read.table(paste("jobStats/", files[i], sep ="\t", header = T))
#  name <- gsub(pattern = "_nr.txt",replacement = "", x = files[i])
#  pdata <- plot(x = data$ElapsedTimeHr, y = data$MemUsedGB, main = name)
#}
#dev.off()
