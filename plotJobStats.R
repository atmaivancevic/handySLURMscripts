#!/usr/bin/env Rscript

# R script to make a scatter plot of mem used vs elapsed (real) time
# Example usage:
# Rscript --vanilla plotJobStats.R BWA_highmem_jobs_nr.txt BWA_highmem_jobs_MEMvsElapsedTime.pdf BWA_highmem_jobs_MEMvsCPUTime.pdf

args = commandArgs(trailingOnly=TRUE)
# args[1] = input file
# args[2] = output file 1
# args[3] = output file 2

# test if there is at least one argument: if not, return an error
if (length(args)==0) {
  stop("At least one argument must be supplied (input file).n", call.=FALSE)
} else if (length(args)==1) {
  # default output file
  args[2] = "output.pdf"
}

setwd("/Users/ativ2716/jobStats/")
pdf(file = args[2])
data <- read.table(args[1], sep ="\t", header = T)
title <- gsub(pattern = "_nr.txt",replacement = "", x = args[1])
pdata <- plot(x = data$ElapsedTimeHr, y = data$MemUsedGB, main = title, xlab="Elapsed Time (hr)", ylab="Memory Used (gb)", xlim = range(pretty(c(0,max(data$ElapsedTimeHr)))), ylim = range(pretty(c(0,max(data$MemUsedGB)))))
dev.off()

setwd("/Users/ativ2716/jobStats/")
pdf(file = args[3])
data <- read.table(args[1], sep ="\t", header = T)
title <- gsub(pattern = "_nr.txt",replacement = "", x = args[1])
pdata <- plot(x = data$CPUTimeHr, y = data$MemUsedGB, main = title, xlab="CPU Time (hr)", ylab="Memory Used (gb)", xlim = range(pretty(c(0,max(data$CPUTimeHr)))), ylim = range(pretty(c(0,max(data$MemUsedGB)))))
dev.off()

q(save="yes")
