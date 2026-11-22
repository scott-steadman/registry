class Registry::RegistryController < ::ApplicationController

  # Registry.configure installs the blocks it is given (permission_check,
  # user_id, user_name) as methods on this module rather than on the controller
  # itself, so that clearing one restores the default defined below instead of
  # removing it from the controller for the rest of the process.
  CONFIG_OVERRIDES = Module.new
  prepend CONFIG_OVERRIDES

  def index
    # Render the UI in an iframe to prevent conflicts between ExtJS and the hosting app's javascript library.
  end

  def viewport
    @root = Registry::Entry.root
    render :layout => false
  end

  def delete_folder
    unless params[:node].index('xnode')
      node = Registry::Folder.find_by_id(params[:node])
      node.destroy if node
    end
    render :plain => 'done'
  end

  def folders
    folders = []
    node = Registry::Entry.root if params[:node] == Registry::Entry::ROOT_ACCESS_KEY
    node = Registry::Entry.find_by_id(params[:node]) unless node
    node.folders.each do |child|
      folders << child.to_folder_hash
    end
    render :json => folders
  end

  def folder
    results = {:success => true, :total => 1, :folders => []}

    if request.post?
      if params[:folder_id].blank? or params[:folder_id].index('xnode')
        fld = Registry::Folder.create(folder_params.merge(:parent => parent, :user_id => registry_user_id))
      else
        fld = Registry::Entry.find(params[:folder_id])
        fld.update(folder_params.merge(:user_id => registry_user_id))
      end
    else
      fld = Registry::Entry.find_by_id(params[:folder_id]) unless params[:folder_id].blank?
      fld = Registry::Entry.new unless fld
    end

    results[:folders] << fld.to_folder_hash
    render :json => results
  end

  def property
    results = {:success => true, :total => 1, :properties => []}

    if request.post?
      if params[:prop_id].blank?
        prop = Registry::Entry.create(property_params.merge(:parent => parent, :user_id => registry_user_id))
      else
        prop = Registry::Entry.find_by_id(params[:prop_id]) || Registry::Entry.new(:parent => parent)
        prop.update(:key          => params[:property][:key],
                    :label        => params[:property][:label],
                    :description  => params[:property][:description],
                    :value        => params[:property][:value],
                    :user_id      => registry_user_id
                    )
      end
    else
      prop = Registry::Entry.find_by_id(params[:prop_id]) unless params[:prop_id].blank?
      prop = Registry::Entry.new unless prop
    end

    results[:properties] << prop.to_form_property_hash if prop
    render :json => results
  end

  def properties
    results = {:success => true, :total => 0, :properties => []}

    if request.get?
      node = Registry::Entry.find_by_id(params[:node]) unless (params[:node] and params[:node] == 'root')
      node = Registry::Entry.root unless node
      node.properties.each do |item|
        results[:properties] << item.to_grid_property_hash
      end
      results[:total] = node.children.size

    elsif request.put?
      item = Registry::Entry.find_by_id(params[:properties][:id])
      item.update("value" => params[:properties][:value], :user_id => registry_user_id)
      results[:properties] << item.to_grid_property_hash
      results[:total] = 1

    elsif request.delete?
      if node = Registry::Entry.find_by_id(params[:properties])
        node.update(:user_id => registry_user_id)
        node.destroy
      end
    end

    render :json => results
  end

  def revisions
    results = {:success => true, :revisions => []}

    @revisions = Registry::Entry::Version.where(['entry_id = ? OR parent_id = ?', params[:id], params[:id]]).order('id DESC')
    @revisions.each do |revision|
      results[:revisions] << {
        'id'      => revision.id.to_s,
        'label'   => (revision.label.blank? ? revision.key : revision.label).to_s,
        'value'   => revision.value.to_s,
        'user'    => registry_user_name(revision.user_id),
        'updated' => revision.updated_at.in_time_zone.to_s,
        'notes'   => revision.notes.to_s,
      }
    end

    render :json => results
  end

  def export
    Registry::Entry.export!('/tmp/registry.yml')
    send_file('/tmp/registry.yml', :type=>'text/yml', :filename => 'registry.yml')
  end

  def import
    Registry::Entry.import!("#{Rails.root}/config/registry.yml")
    redirect_to :action => :viewport
  end

private

  def parent
    @parent ||= Registry::Entry.find_by_id(params[:parent_id]) || Registry::Entry.root
  end

  # The forms post the record's id alongside the editable fields; the action
  # locates the record from folder_id/prop_id instead, so it isn't permitted
  # here.
  def folder_params
    params.require(:folder).permit(:key, :label)
  end

  def property_params
    params.require(:property).permit(:key, :label, :description, :value)
  end

  def registry_user_id
    -1
  end

  def registry_user_name(id)
    id.to_s
  end

end
