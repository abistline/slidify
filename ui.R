#
# This is the user-interface definition of a Shiny web application. You can
# run the application by clicking 'Run App' above.
#
# Find out more about building applications with Shiny here:
# 
#    http://shiny.rstudio.com/
#

library(shiny)
library(ggplot2)

# Define UI for application that processes a periodic time-series
shinyUI(fluidPage(
  
  # Application title
  titlePanel("Time Domain to Frequency Domain via Fast Fourier Transform"),
  
  # Sidebar with a slider input for frequency range and trace display 
  sidebarLayout(
    sidebarPanel(
       sliderInput("range", "Frequency Range", min=0, max=50000, value=c(1, 49999)),
       radioButtons("traces", "Trace Display:", 
                    c("Individual" = "itrace",
                      "Stacked" = "strace")),
       plotOutput("near", height="300px"),
       plotOutput("far", height="300px")
    ),
    
    # Show power-spectrum plots and indicate uniformity
    mainPanel(
      textOutput("diff"),
      tags$head(tags$style("#diff{font-size: 20px;
                           font-style: italic;  
                           }"
                         )
      ),
      plotOutput("fftnear"),
      plotOutput("fftfar")
    )
  )
))
