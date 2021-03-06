class Import
  extend ActiveModel::Model
  extend  ActiveModel::Naming
  include ActiveModel::Conversion
  include ActiveModel::Validations

  attr_accessor :import_file, :import_model, :import_type, :current_user
  # attr_accessor :roast, :brand

  require 'roo'

  """
    Upload the csv into the database
    Csv will contain a number of measurements grouped together by observation group number
    Each observation group contains a number of measurements
    For each observation group, only one observation is created
    Each row in csv represents a new measurement
  """

  # Declare a global variable measurements to store all the measurement objects
  $measurements = []
  
  $new_observations = []

  # Map the observation group number in csv spreadsheet to a newly created observation id
  # Format : { '1' : 90613, '2': 90614 }
  $observation_id_map = {}
  
  $email_list = []
  $ignore_row = []
  $total_rows
  $import_type
  $new_observation_csv_headers = ["observation_id",  "access",  "user_id", "specie_id"  ,"location_id", "resource_id", "trait_id",  "standard_id",  "methodology_id" ,"value" ,"value_type",  "precision" ,"precision_type" , "precision_upper" ,"replicates", "notes"]

  def initialize(attributes = {})
    attributes.each { |name, value| send("#{name}=", value) }
  end

  """ 
  Function to set the model name for further processing
  Can be called by the controller to pass model name
  Important to let this same import functionality for all the models
  
  """
  def set_model_name(import_model)
    self.import_model = import_model
  end


  def get_email_list
    return $email_list.uniq
  end
  
  def import_save(import_type)

    $import_type = import_type

    allowed_file_extensions = ['.csv', '.xls', '.xlsx']
    if not import_file
      errors.add :base, 'Please Select a File'
      return false
    elsif not allowed_file_extensions.include? File.extname(import_file.original_filename)
      errors.add :base, 'File Type Not Allowed. Only files of type ' + allowed_file_extensions.to_s + ' are allowed'
      return false
    end

    $measurements = []
     
    # Save the unique observation from group of observations in csv
    # Do this only if the uploaded csv is a list of observations
    if import_model.to_s == 'Observation' and import_type == 'new'
      observation_error = save_unique_observations
      if not observation_error
        rollback()
        return false
      end    
    end
    
    imp_items = imported_items

    puts "IMPORT --- imported_items: #{imp_items}".red
    
    puts 'IMPORT --- Checking for any errors in imported observations'.red
    # Check for any errors in imported observations

    any_error = check_add_errors(imp_items)

    if not any_error
      puts "IMPORT --- no error in imported_items".red
    end

    # If there's any error, dont override its value
    # If there's no any error, check if error is present in measurements
    if not $measurements.empty?
      puts "IMPORT --- checking errors for measurements: #{$measurements}".red
      any_error ? check_add_errors($measurements) : any_error = check_add_errors($measurements)
    end
    
    # If there is any error, dont attempt to save
    if any_error
      rollback()
      return false
    end    

    puts "IMPORT --- no error in measurements".red
    
    # If no validation errors, see if there is any mapping error
    # If there is a mapping error, display it and then return
    # If there is no any error, then save it
    # if imported_items.map(&:valid?).all? 

    # Main Code to save the observations 'overwrite / new' begins here

    if $import_type == 'overwrite'
      # First Destroy all the observations and their measurements

      puts "IMPORT --- STARTING IMPORT".red
      puts "IMPORT --- #{imp_items}".red
      
      imp_items.compact.each do |item|
        item.save!
      end

      puts "IMPORT --- Observations saved".red
      puts "IMPORT --- #{$measurements}".red

      $measurements.each(&:save!)

    else

      puts "IMPORT --- STARTING IMPORT".red
      puts "IMPORT --- #{imp_items}".red

      imp_items.compact.each do |item|
        item.save!
      end

      puts "IMPORT --- Observations saved".red
      puts "IMPORT --- #{$measurements}".red

      # Duplicate Measurements might still cause validation errors.
      begin
        $measurements.each(&:save!)
      rescue => e
        errors.add :base, e
        rollback()
        return false
      end

    end
    
    puts 'IMPORT --- All Observations saved.. Saving Measurements now'.red
    
    # Finally verify if the total number of rows is equal to total records imported
    total_records_imported = Measurement.where('observation_id IN (?)', $observation_id_map.values).count
    if $total_rows -1 != total_records_imported
      err_msg = 'Something went wrong during import. Total number of records imported is not equal to total number of rows in csv. <br/>
      Total rows in csv: <b>' +  ($total_rows - 1).to_s + ' </b> <br/>
      Total records imported: <b>' + (total_records_imported).to_s + '</b>'
      errors.add :base,  err_msg.html_safe
      if $import_type == 'new'
        rollback()
      end
      return false
    end


    true
    
  end
  
  private

    def open_spreadsheet
      case File.extname(import_file.original_filename)
        when ".csv" then Roo::CSV.new(import_file.path, csv_options: {encoding: Encoding::ISO_8859_1})
        when ".xls" then Roo::Excel.new(import_file.path)
        when ".xlsx" then Roo::Excelx.new(import_file.path)
      else raise "Unknown file type: #{import_file.original_filename}"
      end
    end
    
    # First Check if there is any error in the items in the list
    # If any errors are present, don't attempt to save. Just Return False
    def check_add_errors(items)
      flag = false
      items = items.compact
      items.each_with_index do |item, index|
        
        if item.errors.any?
          item.errors.full_messages.each do |message|
            errors.add :base, "#{message}"
          end
          flag = true
        end
          
        if not item.valid?
          puts "IMPORT --- item not valid: #{item.inspect}".red
          errors.add :base, item.errors.full_messages
          flag = true
        end
      end
      return flag
    end
    
    # If there's any error in observation or measurement, then rollback the saved observations
    def rollback
      puts 'IMPORT --- rolling back'.red
      puts "#{$observation_id_map}".red
      
      # Todo: Make this efficient
      if $import_type != 'new'
        return
      end
      $observation_id_map.keys().each do |k|
        obs = Observation.find($observation_id_map[k])
        obs.destroy!
      end
    end

    # Save the unique observation from group of observations in csv
    def save_unique_observations
      
      spreadsheet = open_spreadsheet
      header = spreadsheet.row(1)
      $observation_id_map = {}
      """
      if header != $new_observation_csv_headers
        errors.add :base, 'The column headers do not match...'
        return false
      end
      """

      (2..spreadsheet.last_row).map do |i|
        row = Hash[[header, spreadsheet.row(i)].transpose]
        puts "IMPORT --- row: #{row}".red
        if not $observation_id_map.keys().include? row["observation_id"] and row["observation_id"].present?
          specie_id = row["specie_id"]
          trait_id = row["trait_id"]
          if row["access"] == "0"
            acc = true
          else
            acc = false
          end

          puts "IMPORT --- access: #{acc}".red

          o = Observation.new()
          o, specie_id, trait_id = validate_trait_specie_id_name(row, o, i)

          observation_row = { "user_id" => row["user_id"], "access" => acc, "location_id" => row["location_id"], "specie_id" => specie_id, "resource_id" => row["resource_id"], "secondary_id" => row["secondary_id"], "approval_status" => "pending"}
          o.attributes = observation_row.to_hash

          measurement_row = {"user_id" => row["user_id"], "trait_id" => trait_id, "standard_id" => row["standard_id"],  "value" => row["value"], "value_type" => row["value_type"], "precision" => row["precision"], "precision_type" => row["precision_type"], "precision_upper" => row["precision_upper"], "replicates" => row["replicates"], "methodology_id" => row["methodology_id"], "notes" => row["notes"], "approval_status" => "pending"}
          m = Measurement.new
          o = validate_model_ids(row, o, i)
          o = validate_methodology_with_trait(row, o, trait_id, i)

          begin
            puts 'IMPORT --- saving unique observations'.red
            m.attributes = measurement_row.to_hash
            puts "measurement: #{m.inspect}".red
            o.measurements << m
            obs_error = check_add_errors([o])
          
            if obs_error
              puts 'IMPORT --- validation error while saving unique observation'.red
              return false
            end

            o.save!
            $observation_id_map[row["observation_id"]] = o.id
            $ignore_row.append(i)
          rescue => e
            puts 'IMPORT --- error saving unique observations'.red
            errors.add :base, e
            return false
          end
        end
      end
    end

    def imported_items
      spreadsheet = open_spreadsheet
      puts "IMPORT --- file opened: #{import_file.original_filename}".red
      header = spreadsheet.row(1)
      @imported_items ||= load_imported_items
    end

    def load_imported_items
      spreadsheet = open_spreadsheet
      header = spreadsheet.row(1)

      $total_rows = spreadsheet.last_row
      
      if $import_type == "new"
        puts "IMPORT --- import_type: #{$import_type}".red

        # Rename some headers to correspond the database fields
        header[header.index("observation_id")] = "id"
        # header[header.index("access")] = "private"
      
        (2..spreadsheet.last_row).map do |i|
          row = Hash[[header, spreadsheet.row(i)].transpose]
          
          if $ignore_row.include? i
            next
          end
          
          # Instantiate or find observation and measurement in order to be able to add errors into them
          observation = Observation.find_by_id($observation_id_map[row["id"]])
          puts "IMPORT --- id map: #{observation}".red

















          measurement = Measurement.new
          puts "IMPORT --- measurement: #{measurement.inspect}".red
          











          specie_id = row["specie_id"]
          location_id = row["location_id"]
          trait_id = row["trait_id"]

          row = row["access"]

          # Start Validations
                
          observation = validate_model_ids(row, observation, i)
          observation = validate_trait_id(trait_id, row, observation, i)
          
          observation, specie_id, trait_id = validate_trait_specie_id_name(row, observation, i)
                    observation = validate_methodology_with_trait(row, observation, trait_id, i)
          
          # Create the actual rows to be sent into the database for observation and measurements
          observation_row = {"id" => $observation_id_map[row["id"]], "user_id" => row["user_id"], "location_id" => location_id, "specie_id" => specie_id, "resource_id" => row["resource_id"], "secondary_id" => row["secondary_id"] , "private" => row["private"]}

          measurement_row = {"user_id" => row["user_id"], "observation_id" => $observation_id_map[row["id"]],  "trait_id" => trait_id, "standard_id" => row["standard_id"],  "value" => row["value"], "value_type" => row["value_type"], "precision" => row["precision"], "precision_type" => row["precision_type"], "precision_upper" => row["precision_upper"], "replicates" => row["replicates"], "methodology_id" => row["methodology_id"], "notes" => row["notes"],  "approval_status" => "pending"}
          
          # puts "IMPORT --- measurement_row: #{measurement_row}".red
          # Additionally check for any mapping errors
          begin
            observation.attributes = observation_row.to_hash
            measurement.attributes = measurement_row.to_hash
            # TODO : check if following holds true
            observation.measurements << measurement
          rescue => error
            observation.errors[:base] << "The column headers do not match with fields..."
            observation.errors[:base] << error.message
            false
          end
          
          $measurements.append(measurement)
          
          observation.approval_status = "pending"
          # Temporary email list
          $email_list.append("suren.shopushrestha@mq.edu.au")
          puts "IMPORT --- sending back observation: #{observation.inspect}".red

          observation
        end

      elsif $import_type == "overwrite"
        puts "IMPORT --- import_type: #{$import_type}".red

        # Rename some headers to correspond the database fields
        header[header.index("observation_id")] = "id"
        header[header.index("access")] = "private"

        $observation_id_map = {}
        $new_observations = []
        x = 1
      
        (2..spreadsheet.last_row).map do |i|
          row = Hash[[header, spreadsheet.row(i)].transpose]
          




          # Instantiate or find observation and measurement in order to be able to add errors into them
          observation = Observation.find_by_id(row["id"])

          puts "IMPORT --- id map: #{observation}".red
          
#           if not $observation_id_map.values().include? row["id"]
# #            puts "IMPORT --- no observation to overwrite. Making new observation instead.".red
#             $observation_id_map[x] = row["id"]
#             obs_new =  Observation.new
#             x = x + 1
#           else
# #            puts "IMPORT --- observation to overwrite found.".red
#             obs_new = $new_observations[$observation_id_map.values().index(row['id'])]
#           end
#           puts "IMPORT --- id map: #{$observation_id_map}".red
#           puts "IMPORT --- observation found for saving: #{observation.inspect}".red

          measurement = Measurement.new
          puts "IMPORT --- measurement: #{measurement.inspect}".red
          
          # Check if the signed in user is the owner of the observation
          puts "IMPORT --- current_user: #{current_user.id}, user_id of observation to overwrite: #{row['user_id']}".red

          if current_user.id.to_s != row['user_id'] and not current_user.admin?
            observation.errors[:base] << "Row #{i}: Only the owner of the observation can overwrite "
            observation
          end

          specie_id = row["specie_id"]
          location_id = row["location_id"]
          trait_id = row["trait_id"]
          
          row = row["access"]

          # Start Validations

          observation = validate_model_ids(row, observation, i)
          observation = validate_trait_id(trait_id, row, observation, i)
          observation, specie_id, trait_id = validate_trait_specie_id_name(row, observation, i)
          observation = validate_methodology_with_trait(row, observation, trait_id, i)
          
          # Create the actual rows to be sent into the database for observation and measurements
          observation_row = {"id" => row["id"], "user_id" => row["user_id"], "location_id" => location_id, "specie_id" => specie_id, "resource_id" => row["resource_id"], "secondary_id" => row["secondary_id"] , "private" => row["private"]}

          measurement_row = {"user_id" => row["user_id"],  "observation_id" => row["id"],  "trait_id" => row["trait_id"], "standard_id" => row["standard_id"],  "value" => row["value"], "value_type" => row["value_type"], "precision" => row["precision"], "precision_type" => row["precision_type"], "precision_upper" => row["precision_upper"], "replicates" => row["replicates"], "methodology_id" => row["methodology_id"], "notes" => row["notes"],  "approval_status" => "pending"}
          
          # puts "IMPORT --- measurement_row: #{measurement_row}".red

          # Additionally check for any mapping errors
          begin
            observation.attributes = observation_row.to_hash
            measurement.attributes = measurement_row.to_hash
            # obs_new.attributes = observation_row.to_hash
            # obs_new.measurements << measurement
            observation.measurements << measurement
          rescue => error
            observation.errors[:base] << "The column headers do not match with fields..."
            observation.errors[:base] << error.message
            false
          end
          
          $measurements.append(measurement)
          # $new_observations.append(obs_new)
          
          observation.approval_status = "pending"

          # Temporary email list
          $email_list.append("suren.shopushrestha@mq.edu.au")
          puts "IMPORT --- sending back observation: #{observation.inspect}".red

          observation
        end

      elsif import_model.to_s != 'Observation'
        puts 'IMPORT --- uploading non observations'.red
        (2..spreadsheet.last_row).map do |i|
          row = Hash[[header, spreadsheet.row(i)].transpose]
          item = import_model.find_by_id(row["id"]) || import_model.new
          
          begin
            item.attributes = row.to_hash
          rescue => error
            item.errors[:base] << "The column headers do not match with fields..."
            item.errors[:base] << error.message
            false
          end
          
          # Validate user_id
          validate_user(item, item.attributes["user_id"], i)
          
          # Validate latitude
          if item.attributes["latitude"]
            validate_long_lat(item, item.attributes["latitude"], "latitude", -90, 90, i)
          end
          
          # Validate longitude
          if item.attributes["longitude"]
            validate_long_lat(item, item.attributes["longitude"], "longitude",  -180, 180, i)
          end

          # Finally return the item
          item.approval_status = "pending"

          $email_list.append("suren.shopushrestha@mq.edu.au")
          item
        end

      end

    end
    
    # Validations of values in the fields in csv

    # def process_private(row)
    #   # 1. Convert 0 or 1 to true or false for private field
    #   if row["private"] == "0" or row["private"].empty?
    #     row["private"] = true
    #   else
    #     row["private"] = false
    #   end

    #   return row
    # end

    def validate_trait_id(trait_id, row, observation, i)
      # Validate Values based on the traits value range
      begin
        if trait_id
          trait = Trait.find(trait_id)
          if not trait.value_range.nil? and trait.value_range == "" 
            if not trait.value_range.include? row["value"] and not trait.value_range.empty?
              observation.errors[:base] << "Row #{i}: Invalid Value for the trait: " + row["trait_name"] + ".. Values should be within " + trait.value_range
            end
          end
          # Uncomment this in production
          # $email_list.append(trait.user.email) if ((not $email_list.include? trait.user.email) && trait.user.editor)
        end
      rescue
        observation.errors[:base] << "Row #{i}: Error with value"
      end

      return observation
    end

    def validate_trait_specie_id_name(row, observation, i)
      begin
        trait_id = row['trait_id']
        trait_name = row['trait_name']
        specie_id = row['specie_id']
        specie_name = row['specie_name']

        if trait_id and trait_name
          puts 'IMPORT --- both trait_id and trait_name'.red
          trait = Trait.find(trait_id)
          if trait_name.strip.downcase != trait.trait_name.strip.downcase
            puts 'IMPORT --- trait_id,  trait_name MISMATCH'.red
            observation.errors[:base] << "Row #{i}: Trait_id and Trait_name do not match"

          end
        elsif trait_name and not trait_id
          traits = Trait.where("lower(trait_name)  IS ?", trait_name.strip.downcase)
          puts 'IMPORT --- only trait_name'.red
          puts "#{traits.count}".red
          if traits.count == 0
            puts 'IMPORT --- no trait with that trait_name'.red
            observation.errors[:base] << "Row #{i}: Trait with corresponding Trait_name not found in database"
            trait_id = nil
          else
            puts 'IMPORT --- trait found with trait_name'.red
            trait_id = traits[0].id
          end
        elsif trait_id and not trait_name
          puts "IMPORT --- only trait_id: #{trait_id}".red
        end

        if specie_id and specie_name
          specie = Specie.find(specie_id)
          puts 'IMPORT --- both specie_id and specie_name'.red
          if specie_name.strip.downcase != specie.specie_name.strip.downcase
            puts 'IMPORT ---  specie_id and specie_name MISMATCH'.red
            observation.errors[:base] << "Row #{i}: Specie_id and Specie_name do not match"

          end
        elsif specie_name and not specie_id
          species = Specie.where("lower(specie_name)  IS ?", specie_name.strip.downcase)
          puts 'IMPORT --- only specie_name'.red
          if species.count == 0
            puts 'IMPORT --- specie_name error'.red
            observation.errors[:base] << "Row #{i}: Species with corresponding Specie_name not found in database"
            specie_id = nil
          else
            specie_id  = species[0].id
          end
        elsif trait_id and not trait_name
          puts "IMPORT --- only specie_id: #{specie_id}".red
        end

      rescue => e
        observation.errors[:base] << e
      end

#      puts "IMPORT --- trait id name validation: #{trait_id}".red
      return observation, specie_id, trait_id
    end
  
    def validate_user(item, user_id, i)
      if User.where(id: user_id).empty?
        item.errors[:base] << "Row #{i}: Invalid user with id: " + user_id.to_s
      end

    end

    def validate_long_lat(item, val, item_type, start, finish, i)
      puts "IMPORT --- validating #{item_type}".red
      val = val.to_i
      if val < start or val > finish
        item.errors[:base] << "Row #{i}: Invalid #{item_type}: "  + val.to_s + " ( has to be between #{start} and #{finish} ) "
        puts "IMPORT --- latitude error".red
      end
    end
    
    def validate_model_ids(row, observation, i)
      negative_cols = ['observation_id', 'trait_id']
      row.each do |col|
#        puts "IMPORT --- #{col[0]}".red
        if col[0].include? 'id' and col[0].length > 2 and not negative_cols.include? col[0]
          field_name = col[0]
          import_model = field_name.split('_')[0]
          model = import_model.singularize.classify.constantize
          puts "IMPORT --- validating #{model}".red
          begin
            item = model.find(col[1]) if not col[1].nil?
          rescue
            puts 'IMPORT --- in validate_model_ids, cant find model with that id'.red
            observation.errors[:base] << "Row #{i}: Cannot find #{import_model} with id " + col[1]
          end
        end
      end

      return observation
    end

    def validate_methodology_with_trait(row, observation, trait_id, i)

      if not row["methodology_id"].nil? and row["methodology_id"] != ""        
        if not Trait.find(trait_id).methodology_ids.include? row["methodology_id"].to_i
          observation.errors[:base] << "Row #{i}: Trait with id: #{ row["trait_id"]} does not have methodology with id: #{row["methodology_id"]} " 
        else
          puts "IMPORT --- no error, trait: #{row["trait_id"]} methodology: #{row["methodology_id"]}".red
        end
      else
        puts "IMPORT --- methodology not present".red
      end

      return observation
    end


end
