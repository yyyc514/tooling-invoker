module ToolingInvoker
  class InvokeDocker
    include Mandate

    def initialize(job)
      @job = job
    end

    def call
      job_dir = "#{ToolingInvoker.config.jobs_dir}/#{job.id}-#{SecureRandom.hex}"
      input_dir = "#{job_dir}/output"
      zip_file = "#{job_dir}/files.zip"
      FileUtils.mkdir_p(input_dir)
      SyncS3.(job.s3_uri, input_dir)

      ZipFileGenerator.new(input_dir, zip_file).write

      resp = RestClient.post("http://#{job.language}-test-runner:4567/job", {
                               zipped_files: File.read(zip_file),
                               results_filepath: job.results_filepath,
                               exercise: job.exercise
                             })

      json = JSON.parse(resp.body)

      job.context = {
        tool_dir: "",
        job_dir: "",
        stdout: '',
        stderr: ''
      }
      job.invocation_data = {
        cmd: "",
        exit_status: json['exit_status']
      }

      job.result = json['result']
      job.status = job.result ? 200 : 400
    end

    private
    attr_reader :job
  end

  require 'zip'

  # This is a simple example which uses rubyzip to
  # recursively generate a zip file from the contents of
  # a specified directory. The directory itself is not
  # included in the archive, rather just its contents.
  #
  # Usage:
  #   directory_to_zip = "/tmp/input"
  #   output_file = "/tmp/out.zip"
  #   zf = ZipFileGenerator.new(directory_to_zip, output_file)
  #   zf.write()
  class ZipFileGenerator
    # Initialize with the directory to zip and the location of the output archive.
    def initialize(input_dir, output_file)
      @input_dir = input_dir
      @output_file = output_file
    end

    # Zip the input directory.
    def write
      entries = Dir.entries(@input_dir) - %w[. ..]

      ::Zip::File.open(@output_file, ::Zip::File::CREATE) do |zipfile|
        write_entries entries, '', zipfile
      end
    end

    private
    # A helper method to make the recursion work.
    def write_entries(entries, path, zipfile)
      entries.each do |e|
        zipfile_path = path == '' ? e : File.join(path, e)
        disk_file_path = File.join(@input_dir, zipfile_path)

        if File.directory? disk_file_path
          recursively_deflate_directory(disk_file_path, zipfile, zipfile_path)
        else
          put_into_archive(disk_file_path, zipfile, zipfile_path)
        end
      end
    end

    def recursively_deflate_directory(disk_file_path, zipfile, zipfile_path)
      zipfile.mkdir zipfile_path
      subdir = Dir.entries(disk_file_path) - %w[. ..]
      write_entries subdir, zipfile_path, zipfile
    end

    def put_into_archive(disk_file_path, zipfile, zipfile_path)
      zipfile.add(zipfile_path, disk_file_path)
    end
  end
end
