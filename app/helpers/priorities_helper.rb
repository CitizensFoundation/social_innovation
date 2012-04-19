module PrioritiesHelper

  def has_process_documents?
    #TODO: Create optimized ActiveRecrods/SQL for this
    found = false
    @priority.priority_processes.each do |process|
      process.process_documents.each do |document|
        found = true
      end
    end
    found
  end

  def has_process_discussions?
    #TODO: Create optimized ActiveRecrods/SQL for this
    found = false
    @priority.priority_processes.each do |process|
      process.process_discussions.each do |discussion|
        found = true if discussion.process_speech_videos.get_first_published
      end
    end
    found
  end
  
  def get_points_number_text(points_count, total_points,new_points=false)
    if points_count>0
      "<span style=\"color:#666;font-size:0.75em;\"> (#{points_count} af #{total_points})</span>".html_safe
    else
      "<span style=\"color:#666;font-size:0.75em;\"> (#{new_points ? tr("no new points", "helper/priorities") : tr("no points", "helper/priorities")})</span>".html_safe
    end
  end
end