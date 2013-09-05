#
# Copyright 2013 Red Hat, Inc.
#
# This software is licensed to you under the GNU General Public
# License as published by the Free Software Foundation; either version
# 2 of the License (GPLv2) or (at your option) any later version.
# There is NO WARRANTY for this software, express or implied,
# including the implied warranties of MERCHANTABILITY,
# NON-INFRINGEMENT, or FITNESS FOR A PARTICULAR PURPOSE. You should
# have received a copy of GPLv2 along with this software; if not, see
# http://www.gnu.org/licenses/old-licenses/gpl-2.0.txt.

class Api::V1::ContentUploadsController < Api::V1::ApiController
  respond_to :json
  before_filter :find_repository, :only => [:create, :upload_bits, :destroy]
  before_filter :authorize

  def rules
    upload_test = lambda { @repo.product.editable? }

    {
      :create => upload_test,
      :upload_bits => upload_test,
      :destroy => upload_test,
      :index => lambda { true } # TODO: set a permission here
    }
  end

  api :POST, "/repositories/:repo_id/content_uploads", "Create an upload request"
  param :repo_id, :identifier, :required => true, :desc => "repository id"
  def create
    respond :resource => Katello.pulp_server.resources.content.create_upload_request
  end

  api :PUT, "/repositories/:repo_id/content_uploads/:id/upload_bits", "Upload bits"
  param :repo_id, :identifier, :required => true, :desc => "repository id"
  param :id, :identifier, :required => true, :desc => "upload request id"
  param :offset, :number, :required => true, :desc => "the offset at which Pulp will store the file contents"
  param :content, :required => true, :desc => "file contents"
  def upload_bits
    Katello.pulp_server.resources.content.upload_bits(params[:id], params[:offset], params[:content])
    render :nothing => true
  end

  api :DELETE, "/repositories/:repo_id/content_uploads/:id", "Delete an upload request"
  param :repo_id, :identifier, :required => true, :desc => "repository id"
  param :id, :identifier, :required => true, :desc => "upload request id"
  def destroy
    Katello.pulp_server.resources.content.delete_upload_request(params[:id])
    render :nothing => true
  end

  api :GET, "/content_uploads", "List all upload requests"
  def index
    request_list = Katello.pulp_server.resources.content.list_all_requests
    respond :collection => request_list
  end

  private

  def find_repository
    @repo = Repository.find(params[:repository_id])
  end
end
