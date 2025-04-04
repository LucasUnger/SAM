# Function to check and install missing packages
install_if_missing <- function(packages) {
  to_install <- packages[!(packages %in% installed.packages()[, "Package"])]
  if (length(to_install) > 0) {
    install.packages(to_install, dependencies = TRUE)
  }
}

# List of required packages
required_packages <- c("shiny", "shinyFiles", "yaml", "dplyr", "readr", "tidyr")

# Install missing packages
install_if_missing(required_packages)

library(shiny)
library(shinyFiles)
library(yaml)
library(dplyr)
library(readr)
library(tidyr)

# Define UI
ui <- fluidPage(
  titlePanel("SAM"),
  
  sidebarLayout(
    sidebarPanel(
      checkboxGroupInput(
        inputId = "selected_channels",
        label = "Select Channels:",
        choices = c("Channel_2", "Channel_3", "Channel_4", "Channel_5"),
        selected = c("Channel_2", "Channel_3")
      ),
      uiOutput("threshold_inputs"),
      shinyDirButton("input_folder", "Select Input Folder", "Select the input folder"),
      verbatimTextOutput("input_folder_path"),
      shinyDirButton("output_folder", "Select Output Folder", "Select the output folder"),
      verbatimTextOutput("output_folder_path"),
      textInput("yaml_file", "YAML File Name:", value = "config.yaml"),
      actionButton("save_button", "Save Configuration"),
      actionButton("run_button", "Run Script")
    ),
    
    mainPanel(
      h4("Configuration Preview:"),
      verbatimTextOutput("config_preview"),
      h4("Status:"),
      verbatimTextOutput("status")
    )
  )
)

# Define Server
server <- function(input, output, session) {
  
  # Set up shinyFiles roots (e.g., home directory)
  roots <- c(home = normalizePath("~"))
  
  shinyDirChoose(input, "input_folder", roots = roots, session = session)
  shinyDirChoose(input, "output_folder", roots = roots, session = session)
  
  # Reactive to get input folder path
  input_folder_path <- reactive({
    req(input$input_folder)
    selected_path <- parseDirPath(roots = roots, selection = input$input_folder)
    normalizePath(selected_path)
  })
  
  # Reactive to get output folder path
  output_folder_path <- reactive({
    req(input$output_folder)
    selected_path <- parseDirPath(roots = roots, selection = input$output_folder)
    normalizePath(selected_path)
  })
  
  # Display the selected input folder path
  output$input_folder_path <- renderText({ input_folder_path() })
  
  # Display the selected output folder path
  output$output_folder_path <- renderText({ output_folder_path() })
  
  # Generate UI for thresholds
  output$threshold_inputs <- renderUI({
    req(input$selected_channels)
    lapply(input$selected_channels, function(channel) {
      numericInput(inputId = paste0("threshold_", channel), label = paste0("Threshold for ", channel, ":"), value = 50, min = 0, max = 255)
    })
  })
  
  # Generate configuration preview
  config <- reactive({
    req(input$selected_channels, input_folder_path(), output_folder_path())
    thresholds <- sapply(input$selected_channels, function(channel) {
      input[[paste0("threshold_", channel)]]
    })
    list(
      channels = input$selected_channels,
      thresholds = thresholds,
      input_folder = input_folder_path(),
      output_folder = output_folder_path()
    )
  })
  
  output$config_preview <- renderPrint({ config() })
  
  # Save YAML configuration
  observeEvent(input$save_button, {
    req(config())
    output_folder <- output_folder_path()
    if (!dir.exists(output_folder)) dir.create(output_folder, recursive = TRUE)
    yaml_file_path <- file.path(output_folder, input$yaml_file)
    writeLines(as.yaml(config()), yaml_file_path)
    output$status <- renderText({ paste("Configuration saved to", yaml_file_path) })
  })
  
  # Run script from UI
  observeEvent(input$run_button, {
    req(config())  # Ensure config is available
    
    # Get the path to the YAML config file
    yaml_file_path <- file.path(output_folder_path(), input$yaml_file)
    
    # Check if the YAML config file exists
    if (!file.exists(yaml_file_path)) {
      output$status <- renderText("YAML file not found. Please save the configuration first.")
      return(NULL)
    }
    
    # Load the YAML config file
    config <- yaml.load_file(yaml_file_path)
    
    # Extract parameters from the config
    channels <- config$channels
    thresholds <- config$thresholds
    folder_path <- config$input_folder
    output_folder <- config$output_folder
    
    # Initialize a list to store summary information
    data_list <- list()
    
    # Get list of all files in the folder
    all_files <- list.files(path = folder_path, full.names = TRUE)
    
    # Process the files
    without_enlargement_files <- all_files[grepl("without_enlargement", all_files)]
    with_enlargement_files <- all_files[grepl("with_enlargement", all_files)]
    
    without_enlargement_files <- sort(without_enlargement_files)
    with_enlargement_files <- sort(with_enlargement_files)
    
    if (length(without_enlargement_files) == 0 || length(with_enlargement_files) == 0) {
      output$status <- renderText("No matching input files found. Please check file names.")
      return(NULL)
    }
    
    output$status <- renderText({
      paste0("Found ", length(without_enlargement_files), " 'without_enlargement' files and ",
             length(with_enlargement_files), " 'with_enlargement' files.")
    })
    
    for (i in seq_along(without_enlargement_files)) {
      without_file <- without_enlargement_files[i]
      with_file <- with_enlargement_files[i]
      
      common_name <- gsub("_without_enlargement.csv", "", basename(without_file))
      without_df <- read.csv(without_file)
      with_df <- read.csv(with_file)
      
      required_columns <- c("Area", "IntDen")
      if (!all(required_columns %in% names(without_df)) || !all(required_columns %in% names(with_df))) {
        stop(paste("Missing columns in", without_file, "or", with_file))
      }
      
      if (nrow(without_df) != nrow(with_df)) {
        stop(paste("Mismatched rows between", without_file, "and", with_file))
      }
      
      with_df <- with_df %>%
        mutate(Area_diff = Area - without_df$Area,
               IntDen_diff = IntDen - without_df$IntDen,
               new_mean = IntDen_diff / Area_diff)
      
      with_df <- with_df %>% select(X, new_mean)
      
      sample_version <- sub(".*_Channel_(\\d+)_.*", "Channel_\\1", basename(with_file))
      sample_name <- sub("(.*)_Channel_\\d+_.*", "\\1", basename(with_file))
      sample_name <- gsub("_$", "", sample_name)  
      
      colnames(with_df)[2] <- paste0("new_mean_", sample_version)
      
      with_df <- with_df %>% mutate(Sample = sample_name)
      
      if (!is.null(data_list[[sample_name]])) {
        data_list[[sample_name]] <- full_join(data_list[[sample_name]], with_df, by = "X")
      } else {
        data_list[[sample_name]] <- with_df
      }
    }
    
    # Define the function for classification and summarization
    classify_and_summarize <- function(df, channels, thresholds, sample_name) {
      for (i in seq_along(channels)) {
        channel <- channels[i]
        threshold <- thresholds[i]
        column_name <- paste0("new_mean_", channel)
        if (column_name %in% colnames(df)) {
          df[[channel]] <- ifelse(df[[column_name]] > threshold, 1, 0)
        } else {
          warning(paste("Column", column_name, "not found. Skipping."))
        }
      }
      
      total_cells <- nrow(df)
      if (total_cells == 0) return(NULL)
      
      combination_counts <- list()
      for (comb_size in 1:length(channels)) {
        combs <- combn(channels, comb_size, simplify = FALSE)
        for (comb in combs) {
          comb_name <- paste(comb, collapse = "_and_")
          combination_counts[[comb_name]] <- sum(rowSums(df[comb]) == comb_size)
        }
      }
      
      positive_counts <- sapply(channels, function(ch) sum(df[[ch]]))
      positive_percentages <- round((positive_counts / total_cells) * 100, 2)
      
      # New: Count cells positive only for each channel
      only_positive_counts <- sapply(channels, function(ch) {
        sum(df[[ch]] == 1 & rowSums(df[setdiff(channels, ch)]) == 0)
      })
      
      non_expressing_count <- sum(rowSums(df[channels]) == 0)
      
      summary <- data.frame(
        Sample = sample_name,
        Total_Cells = total_cells,
        Non_Expressing = non_expressing_count,
        stringsAsFactors = FALSE
      )
      
      for (ch in channels) {
        summary[[paste0("Total_Positive_", ch)]] <- positive_counts[ch]
        summary[[paste0("Percent_Positive_", ch)]] <- positive_percentages[ch]
        summary[[paste0("Only_Positive_", ch)]] <- only_positive_counts[ch]
      }
      
      for (comb_name in names(combination_counts)) {
        summary[[paste0("Total_Positive_", comb_name)]] <- combination_counts[[comb_name]]
      }
      
      return(summary)
    }
    
    # Generate summary counts for all samples
    summary_counts <- data.frame()  # Initialize as an empty data frame
    for (sample in names(data_list)) {
      df <- data_list[[sample]]
      summary <- classify_and_summarize(df, channels, thresholds, sample_name = sample)
      if (!is.null(summary)) {
        summary_counts <- bind_rows(summary_counts, summary)
      } else {
        warning(paste("No data processed for sample:", sample))
      }
    }
    
    if (nrow(summary_counts) == 0) {
      output$status <- renderText("No valid data was processed. Please check your input files.")
      return(NULL)
    }
    
    # Write output to CSV
    output_file <- file.path(output_folder, "summary_counts.csv")
    write_csv(summary_counts, output_file)
    
    output$status <- renderText({ paste("Summary counts saved to", output_file) })
  })
}

# Run the app
shinyApp(ui = ui, server = server)
