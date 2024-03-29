% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/export.R
\name{save-ggplot-module}
\alias{save-ggplot-module}
\alias{save_ggplot_ui}
\alias{save_ggplot_modal}
\alias{save_ggplot_server}
\title{Save \code{ggplot} module}
\usage{
save_ggplot_ui(id)

save_ggplot_modal(id, title = NULL)

save_ggplot_server(id, plot_rv)
}
\arguments{
\item{id}{Module ID.}

\item{title}{Modal's title.}

\item{plot_rv}{A \code{reactiveValues} with a slot \code{plot} containing a \code{ggplot} object.}
}
\value{
No value. Use in UI & server of shiny application.
}
\description{
Save a \code{ggplot} object in various format and resize it before saving.
}
\examples{
library(shiny)
library(ggplot2)
library(shinyWidgets)


ui <- fluidPage(
  tags$h2("Save a ggplot"),
  selectInput("var", "Variable:", names(economics)[-1]),
  plotOutput("plot", width = "600px"),
  actionButton("save", "Save this plot")
)

server <- function(input, output, session) {
  
  rv <- reactiveValues(plot = NULL)
  
  output$plot <- renderPlot({
    rv$plot <- ggplot(economics) + 
      geom_line(aes(date, !!sym(input$var))) + 
      theme_minimal()
    rv$plot
  })
  
  observeEvent(input$save, {
    save_ggplot_modal("ID", "Save plot")
  })
  save_ggplot_server("ID", rv)
}

if (interactive())
  shinyApp(ui, server)
}
