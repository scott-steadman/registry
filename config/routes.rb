Registry::Engine.routes.draw do

  get 'index',    to: 'registry#index'
  get 'viewport', to: 'registry#viewport'

  # The ExtJS front-end builds these URLs with url_for(action: ...), so every
  # action needs a named route.  The verbs are the ones the front-end actually
  # uses: forms and the tree POST, the restful grid stores PUT/DELETE.
  match 'delete_folder', to: 'registry#delete_folder', via: [:get, :post]
  match 'folder',        to: 'registry#folder',        via: [:get, :post]
  get   'folders',       to: 'registry#folders'
  match 'property',      to: 'registry#property',      via: [:get, :post]
  match 'properties',    to: 'registry#properties',    via: [:get, :put, :delete]
  get   'revisions',     to: 'registry#revisions'
  get   'export',        to: 'registry#export'
  get   'import',        to: 'registry#import'

  get '/', to: 'registry#index'
end
