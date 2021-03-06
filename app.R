library(shiny)
library(synapser)
# Waiter creates a loading screen in shiny
library(waiter)
library(DT)
library(tidyverse)

ui <- fluidPage(

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
)

server <- function(input, output, session) {
  
  session$sendCustomMessage(type="readCookie", message=list())

  observeEvent(input$cookie, {
    # If there's no session token, prompt user to log in
    if (input$cookie == "unauthorized") {
      waiter_update(
        html = tagList(
          img(src = "synapse_logo.png", height = "120px"),
          h3("Looks like you're not logged in!"),
          span("Please ", a("login", href = "https://www.synapse.org/#!LoginPlace:0", target = "_blank"),
               " to Synapse, then refresh this page.")
        )
      )
    } else {
      ### login and update session; otherwise, notify to login to Synapse first
      tryCatch({
        synLogin(sessionToken = input$cookie, rememberMe = FALSE)

        ### update waiter loading screen once login successful
        waiter_update(
          html = tagList(
            img(src = "synapse_logo.png", height = "120px"),
            h3(sprintf("Welcome, %s!", synGetUserProfile()$userName))
          )
        )
        Sys.sleep(2)
        waiter_hide()
      }, error = function(err) {
        Sys.sleep(2)
        waiter_update(
          html = tagList(
            img(src = "synapse_logo.png", height = "120px"),
            h3("Login error"),
            span(
              "There was an error with the login process. Please refresh your Synapse session by logging out of and back in to",
              a("Synapse", href = "https://www.synapse.org/", target = "_blank"),
              ", then refresh this page."
            )
          )
        )

      })

      # Any shiny app functionality that uses synapse should be within the
      # input$cookie observer
      output$title <- renderUI({
        titlePanel(sprintf("Welcome, %s", synGetUserProfile()$userName))
      })
    }
  })
  source("get_synapse_data.R")
  
  # treatment data table
  treatment_table_data <- reactive({
    tbl <- count_file_meta_data
    filtered_tbl <- tbl %>%
      filter(MAGeCKInputType=="treatments")
  })
  
  # table for treatment count files
  output$treatment_table <- renderDataTable({
    treatment_table_data()
  },filter = list(position = 'top', clear = FALSE),options = list(pageLength = 5))
  
  # selected for treatment count files
  output$selected_treatment <- renderPrint({
    selected_row_num <- input$treatment_table_rows_selected
    if (length(selected_row_num)) {
        tbl <- treatment_table_data()
        cat('Treatment files were selected:\n\n')
        cat(tbl[selected_row_num,]$id, sep = ', ')
    }
  })
  
  # control data table
  control_table_data <- reactive({
    tbl <- count_file_meta_data
    filtered_tbl <- tbl %>%
      filter(MAGeCKInputType=="control")
  })
  
  # table for treatment count files
  output$control_table <- renderDataTable({
    control_table_data()
  },filter = list(position = 'top', clear = FALSE),options = list(pageLength = 5))
  
  # selected for treatment count files
  output$selected_control <- renderPrint({
    selected_row_num <- input$control_table_rows_selected
    if (length(selected_row_num)) {
      tbl <- control_table_data()
      cat('Conrol files were selected:\n\n')
      cat(tbl[selected_row_num,]$id, sep = ', ')
    }
  })
  
  # synapse IDs for treamtment and control
  treatment_ids <- reactive({
    ids <- input$treatment_table_rows_selected
    treatment_table_data()[ids,]$id
  })
  
  control_ids <- reactive({
    ids <- input$control_table_rows_selected
    control_table_data()[ids,]$id
  })
  
  # selection list for reference library
  observe({
    x <- input$selected_library
    
    # Can use character(0) to remove all choices
    if (is.null(x))
      x <- character(0)
    
    # Can also set the label and select items
    updateSelectInput(session, "selected_library",
                      choices = library_list,
                      selected = tail(x, 1)
    )
  })
  
  # check whether the comparison name is unique
  observeEvent(input$unique, {
    comparison_name <- input$comparison_name
    if(comparison_name %in% comparison_name_data$name){
      output_text <- "Sorry! Please use another comparison name."
    }else{
      output_text <- "This comparisonn name is unique!"
    }
    output$unique_name <- renderText({output_text})
  })
  
  # yaml file 
  output$config_file <- renderPrint({
    cat("library_fileview: syn22344156\n")
    cat("output_parent_synapse_id: syn21896733\n")
    cat("comparison_name:",input$comparison_name,"\n")
    cat("library_name:",input$selected_library,"\n")
    cat("treatment_synapse_ids:\n",
        paste(lapply(treatment_ids(),function(x)({paste0("  - ",x)})),collapse="\n",sep=""),sep="")
    cat("\ncontrol_synapse_ids:\n",
        paste(lapply(control_ids(),function(x)({paste0("  - ",x)})),collapse="\n",sep=""),sep="")
  })
  
  output$downloadFile <- downloadHandler(
    filename = function() {
      paste(input$comparison_name,"_config",".yaml", sep = "")
    },
    content = function(file) {
      cat("library_fileview: syn22344156\n",
          "output_parent_synapse_id: syn21896733\n",
          "comparison_name: ",input$comparison_name,"\n",
          "library_name: ",input$selected_library,"\n",
          "treatment_synapse_ids:\n",
          paste(lapply(treatment_ids(),function(x)({paste0("  - ",x)})),collapse="\n",sep=""),
          "\ncontrol_synapse_ids:\n",
          paste(lapply(control_ids(),function(x)({paste0("  - ",x)})),collapse="\n",sep=""),
          sep = "",
          file=file)
    },
    contentType = "text/plain"
    )

}

shinyApp(ui = ui, server = server)
