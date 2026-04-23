Registry::Engine.routes.draw do
  root :to => 'registry/registry#index'

  # Explicit routes for all RegistryController actions (alphabetically sorted)
  match 'delete_folder' => 'registry/registry#delete_folder', :as => 'delete_folder'
  match 'export'        => 'registry/registry#export',        :as => 'export'
  match 'folder'        => 'registry/registry#folder',        :as => 'folder'
  match 'folders'       => 'registry/registry#folders',       :as => 'folders'
  match 'import'        => 'registry/registry#import',        :as => 'import'
  match 'parent'        => 'registry/registry#parent',        :as => 'parent'
  match 'properties'    => 'registry/registry#properties',    :as => 'properties'
  match 'property'      => 'registry/registry#property',      :as => 'property'
  match 'revisions'     => 'registry/registry#revisions',     :as => 'revisions'
  match 'viewport'      => 'registry/registry#viewport',      :as => 'viewport'
end
