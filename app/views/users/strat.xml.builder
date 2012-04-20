xml.instruct! :xml, :version => "1.0"
xml.StrategicPlanCore :StartDate => @user.created_at.year.to_s + '-' + @user.created_at.month.to_s + '-' + @user.created_at.day.to_s, :Date => Time.now.year.to_s + '-' + Time.now.month.to_s + '-' + Time.now.day.to_s do
  xml.Submitter :Name => @user.name
  xml.Organization do
    xml.Name @user.name.possessive + " agenda for America"
    xml.Acronym current_instance.base_url_w_sub_instance + "/users/" + @user.to_param
  end
  xml.Vision current_instance.tagline
  xml.Mission current_instance.mission
	for tag in @tags
		xml.goal do
			xml.SequenceIndicator tag.id
			xml.name tr(tag.title,"model/category")
			xml.description
			for idea in tag.ideas.published.top_rank
				xml.objective do
					xml.SequenceIndicator tag.id.to_s + '.' + idea.id.to_s
					xml.name idea.name
					xml.description idea.name
					xml.otherInformation
				end
			end
		end
	end
end