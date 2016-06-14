class ObservationImportsController < ApplicationController
  before_action :contributor
  before_action :logged_in_user

  def new
    @observation_import = ObservationImport.new
  end

  def create
    @observation_import = ObservationImport.new(params[:observation_import])

    if @observation_import.save
      # Save the actual file in the server
      import_file = params[:observation_import][:file]
      save_import_file(import_file)

      redirect_to new_observation_import_path, flash: {success: "Imported observations successfully." }
    else
      render :new
    end
  end

  def approve
    @observations = Observation.where("approved = ? AND id IN (?)", false, Measurement.joins(:trait).where("traits.user_id = ?", current_user.id).map(&:observation_id)).paginate(page: params[:page])
      puts "=============================".red
      puts @observations.inspect
      puts "=============================".red

    @pending = true

    if params[:item_id]
      reject = params[:reject]
      reject ? message = "Observation successfully rejected" : message = "Observation successfully approved"
      
      observation = @observations.find_by_id(params[:item_id])
      if not reject
        observation.approved = true
        observation.save!
      else
        observation.destroy!
      end
      redirect_to observation_imports_approve_path, flash: {success: message } 
    else
      render :approve
    end
  end

  private

    def observation_import_params
      params.require(:observation_import).permit(:file)
    end

    def save_import_file(import_file)
      puts "Imported file saved: #{import_file.original_filename}".red
      
      file_name, extension = import_file.original_filename.split(".")
      file_name = [Time.now.strftime('%Y%m%d_%H%M%S'), file_name, current_user.id, params[:observation_import][:import_type]].join('_')
      file_with_extension = [file_name, extension].join('.')
      File.open(Rails.root.join('public', 'uploads', file_with_extension), 'wb') do |file|
        file.write(import_file.read)
      end
    end


end