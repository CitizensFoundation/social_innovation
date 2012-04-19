# Copyright (C) 2008,2009,2010 Róbert Viðar Bjarnason
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

class PriorityProcess < ActiveRecord::Base  
  belongs_to :process_type
  belongs_to :priority

  has_many :process_documents
  has_many :process_discussions

  acts_as_rateable
  acts_as_tree
  
  def get_all_process_documents_by_stage(stage_sequence_number)
    process_documents.find(:all, :conditions=>["stage_sequence_number = ?",stage_sequence_number], :order=>"sequence_number")
  end

  def get_all_discussions_by_stage(stage_sequence_number)
    process_discussions.find(:all, :conditions=>["stage_sequence_number = ?",stage_sequence_number], :order=>"sequence_number")
  end
  
  def self.latest_updated_priorities(limit)
    last_weeks_discussion = ProcessDiscussion.find(:all, :limit=>limit, :order=>"to_time DESC")
    last_weeks_documents = ProcessDocument.find(:all, :limit=>limit, :order=>"external_date DESC")
    @processes_changed_past_7_days = []
    if not last_weeks_discussion.empty? or not last_weeks_documents.empty?
      if not last_weeks_discussion.empty? and not last_weeks_documents.empty?
        @processes_changed_past_7_days = last_weeks_discussion += last_weeks_documents
      elsif not last_weeks_discussion.empty?
        @processes_changed_past_7_days = last_weeks_discussion
      elsif not last_weeks_documents.empty?
        @processes_changed_past_7_days = last_weeks_documents
      end
      @processes_changed_past_7_days = @processes_changed_past_7_days.sort do |a,b|
        if a.class.to_s=="ProcessDiscussion"
          compare_time_a = a.to_time
        else
          compare_time_a = a.external_date
        end  
        if b.class.to_s=="ProcessDiscussion"
          compare_time_b = b.to_time
        else
          compare_time_b = b.external_date
        end
        compare_time_b<=>compare_time_a
      end
      @processes_changed_past_7_days = @processes_changed_past_7_days.map {|p| p.priority_process.priority }.uniq[0..limit]
    end
    @processes_changed_past_7_days
  end

  def last_changed_at
    discussion = ProcessDiscussion.find(:first, :conditions=>["priority_process_id = ?",self.id], :order=>"to_time DESC")
    document = ProcessDocument.find(:first, :conditions=>["priority_process_id = ?",self.id], :order=>"external_date DESC")
    last=Time.now-5.years  
    last=document.external_date if document and document.external_date > last
    last=discussion.to_time if discussion and discussion.to_time > last
    last
  end
end
