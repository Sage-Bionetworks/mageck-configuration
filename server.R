library(shiny)
library(synapser)
# Waiter creates a loading screen in shiny
library(waiter)
library(DT)
library(tidyverse)

shinyServer(function(input, output, session) {
  
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
  
  # table for count file metadata
  count_file_meta_data <- reactive({
    tbl <- synTableQuery("SELECT * FROM syn21763191",
                         includeRowIdAndRowVersion=FALSE)
    as.data.frame(tbl)
  })
  
  # treatment data table
  treatment_table_data <- reactive({
    tbl <- count_file_meta_data()
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
    tbl <- count_file_meta_data()
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
    
    library_list <- as.data.frame(synTableQuery("SELECT distinct LibraryName FROM syn21763191",
                                  includeRowIdAndRowVersion=FALSE))
    # Can also set the label and select items
    updateSelectInput(session, "selected_library",
                      choices = library_list$LibraryName,
                      selected = tail(x, 1)
    )
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

})
