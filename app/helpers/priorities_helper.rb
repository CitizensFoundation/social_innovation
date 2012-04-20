module PrioritiesHelper

  def get_points_number_text(points_count, total_points,new_points=false)
    if points_count>0
      "<span style=\"color:#666;font-size:0.75em;\"> (#{points_count} af #{total_points})</span>".html_safe
    else
      "<span style=\"color:#666;font-size:0.75em;\"> (#{new_points ? tr("no new points", "helper/priorities") : tr("no points", "helper/priorities")})</span>".html_safe
    end
  end
end