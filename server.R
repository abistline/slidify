#
# This is the server logic of a Shiny web application. You can run the 
# application by clicking 'Run App' above.
#
# Find out more about building applications with Shiny here:
# 
#    http://shiny.rstudio.com/
#

library(shiny)
library(seewave)
library(IRISSeismic)
library(ggplot2)

# Define server logic required to create filtered time and frequency plots
shinyServer(function(input, output) {
   
  textFile = "NE_4.txt"
  sampling_rate = 10^5
  n = 5
  index = 2048
  nearFirst = TRUE
  allData = read.csv(textFile, stringsAsFactors = FALSE, skip = 2, header = FALSE)
  
  # Parse the data into 10 individual records.  
  if (nearFirst == TRUE) {
    for (i in 1:n) {
      assign(paste("nt", i, sep = ""), allData[((i-1)*index+i+1):((i)*index+i), ])
      assign(paste("ft", i, sep = ""), allData[((n-1+i)*index+n+i+2):((n+i)*index+n+i+1), ])
      
    }
  } else {
    for (i in 1:n) {
      assign(paste("ft", i, sep = ""), allData[((i-1)*index+i+1):((i)*index+i), ])
      assign(paste("nt", i, sep = ""), allData[((n-1+i)*index+n+i+2):((n+i)*index+n+i+1), ])
    }
  }
  
  # Create a data frame with time and traces in separate columns
  library(dplyr)
  fdf = cbind(ft1, ft2[,2], ft3[,2], ft4[,2], ft5[,2]) 
  names(fdf) = c("time", "f1", "f2", "f3", "f4", "f5") 
  
  # Create one more column in the data frame with stacked traces while making "time" numeric
  f = mutate(fdf, time=as.numeric(time)*(10^-6), 
             stack=(f1 + f2 + f3 + f4 + f5)/5)
  
  # Repeat the process for the "Near" traces
  ndf = cbind(nt1, nt2[,2], nt3[,2], nt4[,2], nt5[,2])
  names(ndf) = c("time", "n1", "n2", "n3", "n4", "n5")
  n = mutate(ndf, time=as.numeric(time)*10^-6, 
             stack=(n1 + n2 + n3 + n4 + n5)/5)
  tpp = n$time[1]
  
  # Data frame with filtered data from near trace
  bpn = reactive({
    lo=input$range[1]; hi=input$range[2]
    data.frame(time=n$time,
               bpn1=bwfilter(n$n1, f=sampling_rate, from=lo, to=hi),
               bpn2=bwfilter(n$n2, f=sampling_rate, from=lo, to=hi),
               bpn3=bwfilter(n$n3, f=sampling_rate, from=lo, to=hi),
               bpn4=bwfilter(n$n4, f=sampling_rate, from=lo, to=hi),
               bpn5=bwfilter(n$n5, f=sampling_rate, from=lo, to=hi),
               bpnstack=bwfilter(n$stack, f=sampling_rate, from=lo, to=hi))
  })
  
  # Data frame with filtered data from far trace
  bpf = reactive({
    lo=input$range[1]; hi=input$range[2]
    data.frame(time=f$time,
               bpf1=bwfilter(f$f1, f=sampling_rate, from=lo, to=hi),
               bpf2=bwfilter(f$f2, f=sampling_rate, from=lo, to=hi),
               bpf3=bwfilter(f$f3, f=sampling_rate, from=lo, to=hi),
               bpf4=bwfilter(f$f4, f=sampling_rate, from=lo, to=hi),
               bpf5=bwfilter(f$f5, f=sampling_rate, from=lo, to=hi),
               bpfstack=bwfilter(f$stack, f=sampling_rate, from=lo, to=hi)
    )
  })

  # Data frame with FFT of near data
  nbpf = reactive({
    data.frame(freq=(50000/1024)*1:1024, 
               nspec=abs(fft(bpn()[,7])))
  })
  
  # Data frame with FFT of far data
  fbpf = reactive({
    data.frame(freq=(50000/1024)*1:1024,
               fspec=abs(fft(bpf()[,7])))
  })
  # Display the differnce betweeen the two slopes
  nlm = reactive({
    lmodel=lm(nspec ~ freq, data=nbpf()[1:1024,])
    data.frame(slope=lmodel[[1]][2], intercept=lmodel[[1]][1])
  })
  
  flm = reactive({
    lmodel=lm(fspec ~ freq, data=fbpf()[1:1024,])
    data.frame(slope=lmodel[[1]][2], intercept=lmodel[[1]][1])
  })
  
  output$diff = renderText({
    paste("Sum of Slope (minimize for maximum frequency uniformity):",
          round((nlm()[[1]] + flm()[[1]])*100000, 4))
  })
  
  # Plot the near trace in the sidebar panel
  output$near <- renderPlot({
    nplot = switch(input$traces,
                   itrace = ggplot() +
                     geom_line(data=bpn(), aes(x=time, y=bpn1), color="green") +
                     geom_line(data=bpn(), aes(x=time, y=bpn2), color="orange") +
                     geom_line(data=bpn(), aes(x=time, y=bpn3), color="red") +
                     geom_line(data=bpn(), aes(x=time, y=bpn4), color="blue") +
                     geom_line(data=bpn(), aes(x=time, y=bpn5), color="gray") +
                     xlab("Time (s)") + ylab("Volts") + ggtitle("Individual Traces (Near)"),
                   strace = ggplot() +
                     geom_line(data=bpn(), aes(x=time, y=bpnstack), color="black") +
                     xlab("Time (s)") + ylab("Volts") + ggtitle("Stacked Traces (Near)"))
    nplot
  })
  
  # Plot the far trace in the sidebar panel
  output$far <- renderPlot({
    fplot = switch(input$traces,
                   itrace = ggplot() +
                     geom_line(data=bpf(), aes(x=time, y=bpf1), color="green") +
                     geom_line(data=bpf(), aes(x=time, y=bpf2), color="orange") +
                     geom_line(data=bpf(), aes(x=time, y=bpf3), color="red") +
                     geom_line(data=bpf(), aes(x=time, y=bpf4), color="blue") +
                     geom_line(data=bpf(), aes(x=time, y=bpf5), color="gray") +
                     xlab("Time (s)") + ylab("Volts") + ggtitle("Individual Traces (Far)"),
                   strace = ggplot() +
                     geom_line(data=bpf(), aes(x=time, y=bpfstack), color="black") +
                     xlab("Time (s)") + ylab("Volts") + ggtitle("Stacked Traces (Far)"))
    fplot
  })
  
  # Plot the fft of the near wave
  output$fftnear <- renderPlot({
    ggplot() + geom_line(data=nbpf()[1:1024,], aes(x=freq, y=nspec)) +
    geom_abline(slope=nlm()[[1]], intercept=nlm()[[2]], colour="blue") +
    annotate("text", x=45000, y=nlm()[[1]]*45000+nlm()[[2]]*2,
             label=paste("Slope*Nyquist Frequency = ", round(nlm()[[1]]*100000, 4))) +
    xlab("Frequency (Hz)") + ylab("Amplitude") + ggtitle("Spectrum 1 (Near)")
  })
  
  # Plot the fft of the far wave
  output$fftfar <- renderPlot({
    ggplot() + geom_line(data=fbpf()[1:1024,], aes(x=freq, y=fspec)) +
    geom_abline(slope=flm()[[1]], intercept=flm()[[2]], colour="blue") +
    annotate("text", x=45000, y=flm()[[1]]*45000+flm()[[2]]*2,
             label=paste("Slope*Nyquist Frequency = ", round(flm()[[1]]*100000, 4))) +
    xlab("Frequency (Hz)") + ylab("Amplitude") + ggtitle("Spectrum 2 (Far)")
  })
})
