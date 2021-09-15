shinyUI(fluidPage(

  tags$head(
    singleton(
      includeScript("www/readCookie.js")
    )
  ),
  
  # Application title
  uiOutput("title"),

  # Sidebar with a slider input for number of bins
  titlePanel("Build MAGeCK configuration file"),
  
  fluidRow(
    h3("1. Select the treatment count files"),
    column(width = 11, offset = 1,
           dataTableOutput('treatment_table'),
           verbatimTextOutput('selected_treatment')
    ),
    
  ),
  fluidRow(
    h3("2. Select the control count files"),
    column(width = 11, offset = 1,
           dataTableOutput('control_table'),
           verbatimTextOutput('selected_control')
    ),
  ),
  fluidRow(
    h3("3. Select the reference library"),
    column(width = 11, offset = 1,
           selectInput('selected_library', "Library Name",choices = c())
    )
  ),
  fluidRow(
    h3("4. Enter the comparison name"),
    h5("Please give a meaningful comparison name and check whether it is unique.
       For example, 20201230_Dragonite_Lat_CUL3"),
    column(width = 11, offset = 1,
           textInput('comparison_name',"Comparison Name"),
           actionButton("unique", "Check Uniqueness"),
           verbatimTextOutput('unique_name')
    )
  ),
  fluidRow(
    h3("5. Download the yaml file"),
    column(width = 11, offset = 1,
           verbatimTextOutput('config_file'),
           downloadButton('downloadFile')
    )
  ),
  use_waiter(),
  waiter_show_on_load(
    html = tagList(
      img(src = "loading.gif"),
      h4("Retrieving Synapse information...")
    ),
    color = "#424874"
  )
))
