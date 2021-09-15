# Get data from Synapse for the app


download_synapse_table <- function(table_id){
  tbl <- synTableQuery(paste("SELECT * FROM",table_id),
                       includeRowIdAndRowVersion=FALSE)
  return(as.data.frame(tbl))
}

# table for count file metadata
count_file_meta_data <- download_synapse_table("syn21763191")

# table for comparison name
comparison_name_data <- download_synapse_table("syn25435509")

# list of current libraries
library_list <- na.omit(unique(count_file_meta_data$LibraryName))
