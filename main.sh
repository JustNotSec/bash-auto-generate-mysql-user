#!/bin/bash

# Handle arguments passed to the script
CATEGORY=$1

# Make function to print the usage
#
# Return:
# void
function print_usage() {
  echo "===================================="
  echo "Argument category is required"
  echo "Usage: ./insert.sh <category>"
  echo "Category: <up | down>"
  echo "Example: ./insert.sh up"
  echo "===================================="
}

# Check if the category is empty
if [ -z "$CATEGORY" ]; then
  print_usage
  echo "Program exited"
  exit 1
fi

# Check if the category is not up or down
if [ "$CATEGORY" != "up" ] && [ "$CATEGORY" != "down" ]; then
  print_usage
  echo "Program exited"
  exit 1
fi

# Init variable to store file path
FILE_PATH="data"

# Init variable to store output path
OUTPUT_PATH="output"

# Init variable to store salt path
SALT_PATH="salt"

# Init array to store configuration
typeset -A config

# Init array to store generated password for each file
typeset -A generated_password

# Set default values, please do not change this
# except you know what you are doing
# This is the default configuration
config=(
  [DB_USERNAME]="root"
  [DB_PASSWORD]=""
  [DB_NAME]="test"
  [USER_HOST]="localhost"
  [TARGET_FILE]="nim_kelas_test.txt"
)

# Read the configuration file and set the values from generate.conf
# If the configuration file is not found, use the default values
# If the configuration file is found, override the default values
while IFS='=' read -r key value; do
  # If the line is empty, or if key and value is empty, then skip
  if [ -z "$key" ] || [ -z "$value" ]; then
    continue
  fi

  # Unwrap the value
  value=$(echo $value | sed 's/^"\(.*\)"$/\1/')

  # Set the value to the key
  config[$key]=$value
done < generate.conf

# Check if there is any file exists with the pattern
# from file_path variable and target_file variable
if [ "$CATEGORY" == "up" ] && [ ! -f "$FILE_PATH/${config[TARGET_FILE]}" ]; then
  echo "File $FILE_PATH/${config[TARGET_FILE]} not found"
  exit 1
fi

# Check if the output file is exists
# if exists then remove the file inside the folder
# but only remove when category is up
if [ "$CATEGORY" == "up" ] && [ -f "$OUTPUT_PATH/${config[TARGET_FILE]}" ]; then
  # Print the message that we are deleting the file
  echo "Deleting file $OUTPUT_PATH/${config[TARGET_FILE]}"

  # Remove the file in try catch block
  rm $OUTPUT_PATH/${config[TARGET_FILE]} || {
    echo "Failed to delete file $OUTPUT_PATH/${config[TARGET_FILE]}"
    exit 1
  }

  # Print the message if the file is deleted
  echo "File $OUTPUT_PATH/${config[TARGET_FILE]} deleted"
fi

declare -a word_data
word_data_length=0

# Make function to load salt folder
# which mean 2 file will be assign to different
# variable, for word and symbol
#
# Parameter:
# $1: salt
#
# Return:
# void
function load_salt_folder() {
  # Load the salt folder
  local salt=$1

  # Check if the salt folder is exists
  if [ ! -d $salt ]; then
    echo "Salt folder $salt not found"
    exit 1
  fi

  if [ ! -f $SALT_PATH/word.txt ]; then
    echo "Word file on path $SALT_PATH/word.txt not found"
    exit 1
  fi

  local index=0

  while IFS= read -r line; do
    word_data[$index]=$line
    index=$((index+1))
  done < $SALT_PATH/word.txt

  word_data_length=$index
}

# Load the salt folder
# only when the category is up
if [ "$CATEGORY" == "up" ]; then
  load_salt_folder $SALT_PATH
fi

# Make function to make output file
# The output file will be named as the input file
# but with value "nim | password" for each line
#
# Parameter:
# $1: nim
# $2: password
#
# Return:
# void
function make_output_file() {
  # so we will create the output file
  # based on parameter passed to this function
  # the parameter is nim and password

  # Get the nim
  local nim=$1

  # Get the password
  local password=$2

  # Write the output to the file
  echo "$nim | $password" >> $OUTPUT_PATH/${config[TARGET_FILE]}
}

# Make function to generate random password
# generated password must be unique based on the nim
# for each nim, the password must be the same
# and length of the password must be 8 characters
# and return the password
#
# Parameter:
# $1: nim
#
# Return:
# string - generated password
function generate_password() {
  # Generate 3 random number
  local random_number=$((100 + RANDOM % 900))
  local number=$(echo $random_number | cut -d ' ' -f 1)

  # Generate the last digit of nim
  # and make it as the index of word_data
  local nim_last_digit=$(echo $1 | tail -c 2)

  # Generate random index
  # to get the word from the word_data
  local random_index=$((nim_last_digit + RANDOM % word_data_length - nim_last_digit - 1))

  # Generate the password
  local password=$(echo ${word_data[random_index]})

  # Check if generated password is already generated
  # using loop to check if the password is already generated
  # if the password is already generated, then generate the password again
  # until the password is unique
  while [ -n "${generated_password[$number]}" ]; do
    if [ "${generated_password[$number]}" != "$1" ]; then
      # If the number is already generated
      # Increment the random number by 1
      # until the number is unique
      number=$number+1

      continue
    fi
  done

  # Store the generated password to the array
  generated_password[$number]=$password

  # Return the password
  # and parse the password to the caller
  echo "$password$number"
}

# Make function to create user, database, and grant privileges
#
# Parameter:
# $1: nim
#
# Return:
# void
function create_user_database() {
  # Generate the password
  local password=$(generate_password $1)

  # If database password is empty
  # then run mysql command without password
  if [ -z "${config[DB_PASSWORD]}" ]; then
    # Create the user
    mysql -u ${config[DB_USERNAME]} -e "CREATE USER IF NOT EXISTS '$1'@'${config[USER_HOST]}' IDENTIFIED BY '$password';"
  else 
    # Create the user
    mysql -u ${config[DB_USERNAME]} -p${config[DB_PASSWORD]} -e "CREATE USER IF NOT EXISTS '$1'@'${config[USER_HOST]}' IDENTIFIED BY '$password';"
  fi

  # Print the user name
  echo "User $1 created for host ${config[USER_HOST]}"

  # If database password is empty
  # then run mysql command without password
  if [ -z "${config[DB_PASSWORD]}" ]; then
    # Grant privileges
    mysql -u ${config[DB_USERNAME]} -e "GRANT ALL PRIVILEGES ON \`$1\_%\`.* TO '$1'@'${config[USER_HOST]}';"
  else 
    # Grant privileges
    mysql -u ${config[DB_USERNAME]} -p${config[DB_PASSWORD]} -e "GRANT ALL PRIVILEGES ON \`$1\_%\`.* TO '$1'@'${config[USER_HOST]}';"
  fi

  # Print the privileges
  echo "Privileges granted for $1\_%.* on host ${config[USER_HOST]}"

  # If database password is empty
  # then run mysql command without password
  if [ -z "${config[DB_PASSWORD]}" ]; then
    # Create the database
    mysql -u ${config[DB_USERNAME]} -e "CREATE DATABASE IF NOT EXISTS $1_${config[DB_NAME]};"
  else 
    # Create the database
    mysql -u ${config[DB_USERNAME]} -p${config[DB_PASSWORD]} -e "CREATE DATABASE IF NOT EXISTS $1_${config[DB_NAME]};"
  fi

  # Print the database name
  echo "Database $1_${config[DB_NAME]} created"

  # Call the function to make output file
  make_output_file $1 $password
}

# Make function to drop user, database, and revoke privileges
#
# Parameter:
# $1: nim
#
# Return:
# void
function drop_user_database() {
  # If database password is empty
  # then run mysql command without password
  if [ -z "${config[DB_PASSWORD]}" ]; then
    # Drop default database with prefix nim
    mysql -u ${config[DB_USERNAME]} -e "DROP DATABASE IF EXISTS $1_${config[DB_NAME]};"
  else 
    # Drop default database with prefix nim
    mysql -u ${config[DB_USERNAME]} -p${config[DB_PASSWORD]} -e "DROP DATABASE IF EXISTS $1_${config[DB_NAME]};"
  fi

  # Print the database name
  echo "Database $1_${config[DB_NAME]} dropped"

  # If database password is empty
  # then run mysql command without password
  if [ -z "${config[DB_PASSWORD]}" ]; then
    # Drop the user
    mysql -u ${config[DB_USERNAME]} -e "DROP USER IF EXISTS '$1'@'${config[USER_HOST]}';"
  else 
    # Drop the user
    mysql -u ${config[DB_USERNAME]} -p${config[DB_PASSWORD]} -e "DROP USER IF EXISTS '$1'@'${config[USER_HOST]}';"
  fi

  # Print the user name
  echo "User $1 dropped for host ${config[USER_HOST]}"
}

# Make function to read file and loop through the file
# to get the content of the file
#
# Return:
# void
function read_and_loop_file() {
  # Check if the file is empty
  if [ ! -s $FILE_PATH/${config[TARGET_FILE]} ]; then
    echo "File $FILE_PATH/${config[TARGET_FILE]} is empty"
    continue
  fi

  # Loop through the file
  while IFS= read -r line; do
    local nim=$(echo $line | cut -d ' ' -f 1)

    # Print separator
    echo "======================================="

    # Check category data
    # if category is up then create user and database
    # if category is down then drop user and database
    if [ "$CATEGORY" == "up" ]; then
      create_user_database $nim
    elif [ "$CATEGORY" == "down" ]; then
      drop_user_database $nim
    fi

    # If database password is empty
    # then run mysql command without password
    if [ -z "${config[DB_PASSWORD]}" ]; then
      # Flush privileges
      mysql -u ${config[DB_USERNAME]} -e "FLUSH PRIVILEGES;"
    else 
      # Flush privileges
      mysql -u ${config[DB_USERNAME]} -p${config[DB_PASSWORD]} -e "FLUSH PRIVILEGES;"
    fi

    # Print the flush privileges
    echo "Privileges flushed"

    # Print separator
    echo "======================================="

    # Print the message that we are sleeping
    echo "Sleeping for 1 second"

    # Do sleep for 1 second
    # to prevent lack of resources
    sleep 1
  done < $FILE_PATH/${config[TARGET_FILE]}
}

# Call the function to read and loop the file
read_and_loop_file

# Print the completion message
if [ "$CATEGORY" == "up" ]; then
  echo "All users and databases created"
elif [ "$CATEGORY" == "down" ]; then
  echo "All users and databases dropped"
fi
