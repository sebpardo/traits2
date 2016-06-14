class ObservationImport
  extend ActiveModel::Model
  include ActiveModel::Conversion
  include ActiveModel::Validations

  attr_accessor :file, :import_type, :user_id



  def initialize(attributes = {})
    attributes.each { |name, value| send("#{name}=", value) }
  end

  def persisted?
    false
  end



  def save
    puts "IMPORT: #{import_type}".red

    # valid file
    allowed_file_extensions = ['.csv', '.xls', '.xlsx']
    if not file
      errors.add :base, 'Please select a file'
      return false
    elsif not allowed_file_extensions.include? File.extname(file.original_filename)
      errors.add :base, 'Only files of type ' + allowed_file_extensions.to_s + ' are allowed'
      return false
    end

    any_error = check_add_errors(imported_observations)

    if errors[:base].present?
      any_error = true
    end

    puts "KKKKLKKKKLKKKKLKKKKLKKKKLKKKKLKKKKLKKKKLKKKKL"
    puts any_error
    puts "KKKKLKKKKLKKKKLKKKKLKKKKLKKKKLKKKKLKKKKLKKKKL"


    if any_error
      false
    else
      imported_observations.each(&:save!)
      true
    end
  end

  def imported_observations
    @imported_observations ||= load_imported_observations
  end

  def load_imported_observations
    spreadsheet = open_spreadsheet

    # Get header and change a few header names to match database
    header = spreadsheet.row(1)
    puts "header: #{header}".red

    required_headers = ["observation_id", "access", "user_id", "location_id", "standard_id", "methodology_id", "value", "precision", "precision_upper", "replicates", "notes"]

    required_flag = true
    
    puts "FLAG: #{required_flag}".red
    
    required_headers.each do |r|
      if not header.include? r
        errors.add :base, "Missing header for #{r}"
        required_flag = false
      end
    end

    if not header.include? "specie_name" and not header.include? "specie_id"
      errors.add :base, "Missing header for either specie_id or specie_name"
      required_flag = false
    end

    if not header.include? "trait_name" and not header.include? "trait_id"
      errors.add :base, "Missing header for either trait_id or trait_name"
      required_flag = false
    end

    if not header.include? "resource_doi" and not header.include? "resource_id"
      errors.add :base, "Missing header for either resource_doi or resource_id"
      required_flag = false
    end

    if not header.include? "value_type_id" and not header.include? "value_type_name"
      errors.add :base, "Missing header for either value_type_id or value_type_name"
      required_flag = false
    end

    if not header.include? "precision_type_id" and not header.include? "precision_type_name"
      errors.add :base, "Missing header for either precision_type_id or precision_type_name"
      required_flag = false
    end
  
    if required_flag == false
      return false
    else

      header[header.index("observation_id")] = "id"

      observation_marker = "-1"

      (2..spreadsheet.last_row).map do |i|
        row = Hash[[header, spreadsheet.row(i)].transpose]


        puts "Row #{i}: '#{row["access"]}'".green

        # 1. Convert 0 or 1 to true or false for private field
        if row["access"] == "1" or row["access"] == "true" or row["access"].blank?
          row["access"] = true
        else
          row["access"] = false
        end

        puts "Row #{i}: '#{row["access"]}'".blue


        if row["specie_name"]
          specie = Specie.where("specie_name = ?", row["specie_name"])
          puts "=== Specie: #{specie.inspect}".red
          if specie.empty?
            errors[:base] << "Row #{i}: Species name '#{row["specie_name"]}' does not exist"
            puts "Row #{i}: Species name '#{row["specie_name"]}' does not exist".blue
          else
            if not row["specie_id"] or row["specie_id"].blank?
              row["specie_id"] = specie.first.id
              puts "=== Here 1".green

            elsif specie.first.id != row["specie_id"].to_i
              puts "=== Here 2".green
              errors[:base] << "Row #{i}: Species name '#{row["specie_name"]}' does not match species_id=#{specie.first.id}"
            end
          end
        end

        if row["trait_name"]
          trait = Trait.where("trait_name = ?", row["trait_name"])
          puts "=== Trait: #{trait.inspect}".red
          if trait.empty?
            errors[:base] << "Row #{i}: Measurement trait name does not exist"
          else
            if not row["trait_id"] or row["trait_id"].blank?
              row["trait_id"] = trait.first.id
            elsif trait.first.id != row["trait_id"].to_i
              errors[:base] << "Row #{i}: Trait name '#{row["trait_name"]}' does not match trait_id=#{trait.first.id}"
            end
          end
        end

        if row["resource_doi"]
          resource = Resource.where("doi_isbn = ?", row["resource_doi"])
          puts "=== DOI: #{resource.inspect}".red
          if resource.empty?
            begin
              @doi = JSON.load(open("http://api.crossref.org/works/#{row["resource_doi"]}"))
              if @doi["message"]["author"][0]["family"] == "Peresson"
                @doi = "Invalid"
              end
            rescue
              @doi = "Invalid"
            end

            if @doi and not @doi == "Invalid"
              @resource = Resource.new
              @resource.doi_isbn = row["resource_doi"]

              authors = ""
              @doi["message"]["author"].each do |a|
                authors = authors + "#{a["family"].titleize}, #{a["given"].titleize}, "
              end

              @resource.author = authors
              @resource.year = @doi["message"]["issued"]["date-parts"][0][0]
              @resource.title = @doi["message"]["title"][0]
              @resource.journal = @doi["message"]["container-title"][0]
              @resource.volume_pages = "#{@doi["message"]["volume"]}, #{@doi["message"]["page"]}"

              @resource.save!

              row["resource_id"] = @resource.id

              puts "------------------------------- HERE ============================="
              puts @resource.id
            else
              errors[:base] << "Row #{i}: DOI does not resolve"
            end

          else
            if not row["resource_id"] or row["resource_id"].blank?
              row["resource_id"] = resource.first.id
              puts "------------------------------- HERE ============================="
              puts resource.first.id
            elsif resource.first.id != row["resource_id"].to_i
              errors[:base] << "Row #{i}: Resource doi '#{row["resource_doi"]}' does not match resource_id=#{resource.first.id}"
            end
          end
        end

        if row["resource_secondary_doi"]
          resource = Resource.where("doi_isbn = ?", row["resource_secondary_doi"])
          puts "=== DOI: #{resource.inspect}".red
          if resource.empty?
            begin
              @doi = JSON.load(open("http://api.crossref.org/works/#{row["resource_secondary_doi"]}"))
              if @doi["message"]["author"][0]["family"] == "Peresson"
                @doi = "Invalid"
              end
            rescue
              @doi = "Invalid"
            end

            if @doi and not @doi == "Invalid"
              @resource = Resource.new
              @resource.doi_isbn = row["resource_secondary_doi"]

              authors = ""
              @doi["message"]["author"].each do |a|
                authors = authors + "#{a["family"].titleize}, #{a["given"].titleize}, "
              end

              @resource.author = authors
              @resource.year = @doi["message"]["issued"]["date-parts"][0][0]
              @resource.title = @doi["message"]["title"][0]
              @resource.journal = @doi["message"]["container-title"][0]
              @resource.volume_pages = "#{@doi["message"]["volume"]}, #{@doi["message"]["page"]}"

              @resource.save!

              row["resource_secondary_id"] = @resource.id

              puts "------------------------------- HERE ============================="
              puts @resource.id
            else
              errors[:base] << "Row #{i}: Secondary resource DOI does not resolve"
            end

          else
            if not row["resource_secondary_id"] or row["resource_secondary_id"].blank?
              row["resource_secondary_id"] = resource.first.id
            elsif resource.first.id != row["resource_secondary_id"].to_i
              errors[:base] << "Row #{i}: Secondary resource doi '#{row["resource_secondary_doi"]}' does not match secondary resource_id=#{resource.first.id}"
            end
          end
        end


        # puts "#{row["specie_id"].inspect}".blue
        # puts "#{Observation.where("specie_id IS ?", row["specie_id"]).inspect}".blue

        if observation_marker != row["id"]
          $observation = Observation.new
          if row["id"].blank?
            $observation.errors[:base] << "Row #{i}: Observation id is empty"
          end

          observation_row = {"id" => $observation.id, "user_id" => row["user_id"], "location_id" => row["location_id"], "specie_id" => row["specie_id"], "resource_id" => row["resource_id"], "resource_secondary_id" => row["resource_secondary_id"] , "access" => row["access"]}
          $observation.attributes = observation_row.to_hash
          $observation.approved = "pending"

          observation_marker = row["id"]
        else
          $observation = validate_observation_consistency(i, row)
        end

        $observation = validate_observation_exist(i, row)
        $observation = validate_public_resource(i, row)


        value_type = Valuetype.where("value_type_name = ?", row["value_type_name"])
        puts "=== Valuetype: #{value_type.inspect}".red
        if value_type.empty?
          errors[:base] << "Row #{i}: Measurement value type name does not exist"
        else
          row["valuetype_id"] = value_type.first.id
        end

        if row["precision_type_name"]
          precision_type = Precisiontype.where("precision_type_name = ?", row["precision_type_name"])
          puts "=== Precisiontype: #{precision_type.inspect}".red
          if precision_type.empty?
            errors[:base] << "Row #{i}: Measurement precision type name does not exist"
          else
            row["precisiontype_id"] = precision_type.first.id
          end
        end

        measurement = $observation.measurements.build

        measurement_row = {"observation_id" => $observation.id,  "trait_id" => row["trait_id"], "standard_id" => row["standard_id"],  "value" => row["value"], "valuetype_id" => row["valuetype_id"], "precision" => row["precision"], "precisiontype_id" => row["precisiontype_id"], "precision_upper" => row["precision_upper"], "replicates" => row["replicates"], "methodology_id" => row["methodology_id"], "measurement_description" => row["notes"]}

        measurement.attributes = measurement_row.to_hash

        $observation = validate_measurement_exist(i, row)

        # if row["methodology_id"]

        #   methodology = Methodology.where("id = ?", row["methodology_id"])
        #   # puts "=== Precisiontype: #{precision_type.inspect}".red
        #   if methodology.empty?
        #     errors[:base] << "Row #{i}: Methodology does not exist"
        #   else
        #     MeasurementsMethodology.create(:measurement_id => measurement.id, :methodology_id  => row["methodology_id"])
        #     # measurements_methodology.measurement_id = measurement.id
        #     # measurements_methodology.methodology_id = methodology
        #     # measurements_methodology.save!
        #   end
        # end

        $observation
      end
    end
  end

  def open_spreadsheet
    case File.extname(file.original_filename)
    when ".csv" then Roo::CSV.new(file.path, csv_options: {encoding: Encoding::ISO_8859_1})
    when ".xls" then Excel.new(file.path, nil, :ignore)
    when ".xlsx" then Excelx.new(file.path, nil, :ignore)
    else raise "Unknown file type: #{file.original_filename}"
    end
  end

  private

    def validate_measurement_exist(i, row)
      if row["trait_id"].blank?
        $observation.errors[:base] << "Row #{i}: Trait_id is blank"
      elsif Trait.where("id = ?", row["trait_id"]).blank?
        $observation.errors[:base] << "Row #{i}: Trait with id=#{row["trait_id"]} doesn't exist"
      end
      if row["standard_id"].blank?
        $observation.errors[:base] << "Row #{i}: standard_id is blank"
      elsif Standard.where("id = ?", row["standard_id"]).blank?
        $observation.errors[:base] << "Row #{i}: Standard with id=#{row["standard_id"]} doesn't exist"
      end
      if row["methodology_id"].blank?
      elsif Methodology.where("id = ?", row["methodology_id"]).blank?
        $observation.errors[:base] << "Row #{i}: Methodology with id=#{row["methodology_id"]} doesn't exist"
      end
      if row["value"].blank?
        $observation.errors[:base] << "Row #{i}: Value is blank"
      end
      if row["valuetype_id"].blank?
        $observation.errors[:base] << "Row #{i}: Value type is blank"
      end
      return $observation
    end

    def validate_observation_consistency(i, row)
      $observation.errors[:base] << "Row #{i}: Access should be same for all measurements for a given observation" if $observation.access != row["access"]
      $observation.errors[:base] << "Row #{i}: User_id should be same for all measurements for a given observation" if $observation.user_id != row["user_id"].to_i
      $observation.errors[:base] << "Row #{i}: Specie_id should be same for all measurements for a given observation" if $observation.specie_id != row["specie_id"].to_i
      $observation.errors[:base] << "Row #{i}: Location_id should be same for all measurements for a given observation" if $observation.location_id != row["location_id"].to_i
      $observation.errors[:base] << "Row #{i}: Resource_id should be same for all measurements for a given observation" if $observation.resource_id != row["resource_id"].to_i unless row["resource_id"].blank?

      $observation.errors[:base] << "Row #{i}: Secondary resource_id should be same for all measurements for a given observation" if $observation.resource_secondary_id != row["resource_secondary_id"].to_i unless row["resource_secondary_id"].blank?

      return $observation
    end

    def validate_public_resource(i, row)
      $observation.errors[:base] << "Row #{i}: Resource_id required for public observations" if row["resource_id"].blank? and (row["access"] == false)
      return $observation
    end


    def validate_observation_exist(i, row)
      puts "here #{user_id}"
      puts "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"

      $observation.errors[:base] << "Row #{i}: User_id=#{row["user_id"]} doesn't exist" if User.where("id = ?", row["user_id"]).blank?
      $observation.errors[:base] << "Row #{i}: User_id=#{row["user_id"]} is not your user ID." if (user_id != row["user_id"] and not User.find_by_id(user_id).admin)
      $observation.errors[:base] << "Row #{i}: Specie_id=#{row["specie_id"]} doesn't exist" if Specie.where("id = ?", row["specie_id"]).blank?
      $observation.errors[:base] << "Row #{i}: Location_id=#{row["location_id"]} doesn't exist" if Location.where("id = ?", row["location_id"]).blank?
      $observation.errors[:base] << "Row #{i}: Resource_id=#{row["resource_id"]} doesn't exist" if Resource.where("id = ?", row["resource_id"]).blank?
      $observation.errors[:base] << "Row #{i}: Resource_id=#{row["resource_id"]} doesn't exist and access is public" if (Resource.where("id = ?", row["resource_id"]).blank? and not row["access"]) unless row["resource_id"].blank?

      $observation.errors[:base] << "Row #{i}: Secondary resource_id=#{row["resource_secondary_id"]} doesn't exist" if Resource.where("id = ?", row["resource_secondary_id"]).blank? unless row["resource_secondary_id"].blank?

      return $observation
    end


    def check_add_errors(items)
      flag = false
      if items.present?
        items = items.compact
        items.each_with_index do |item, index|    
          if item.errors.any?
            item.errors.full_messages.each do |message|
              errors.add :base, "#{message}"
            end
            flag = true
          end
            
          # if not item.valid?
          #   item.errors.full_messages.each do |message|
          #     errors.add :base, "Row #{index+2} v: #{message}"
          #   end
          #   flag = true
          # end
        end
      else
        flag = true
      end
      return flag
    end

end