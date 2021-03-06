module Katello
  class ContentViewPuppetModule < Katello::Model
    audited :associated_with => :content_view
    belongs_to :content_view, :class_name => "Katello::ContentView", :inverse_of => :content_view_versions

    validates_lengths_from_database
    validates :content_view_id, :presence => true
    validates :name, :uniqueness => { :scope => :content_view_id, :message => _('There is already a module named "%{value}" in this content view.') }
    validates :uuid, :uniqueness => { :scope => :content_view_id }, :allow_blank => true

    validates_with Validators::ContentViewPuppetModuleValidator

    scoped_search :on => :name, :complete_value => true
    scoped_search :on => :author, :complete_value => true
    scoped_search :on => :uuid, :complete_value => true
    scoped_search :on => :name, :relation => :content_view, :rename => :content_view_name

    before_validation :set_attributes

    validate :import_only_content_view

    def puppet_module
      PuppetModule.find_by(:pulp_id => self.uuid)
    end

    def computed_version
      if self.uuid
        puppet_module = PuppetModule.where(:pulp_id => self.uuid).first
      else
        puppet_module = PuppetModule.latest_module(
          self.name,
          self.author,
          self.content_view.puppet_repos
        )
      end

      puppet_module.try(:version)
    end

    def latest_in_modules_by_author?(puppet_module_list)
      latest_from_list = puppet_module_list.where(:author => self.author).order(:sortable_version => :desc).first
      self.computed_version.eql?(latest_from_list.try(:version))
    end

    private

    def import_only_content_view
      if self.content_view.import_only?
        errors.add(:base, "Cannot add puppet modules to an import-only content view.")
      end
    end

    def set_attributes
      if self.uuid.present?
        puppet_module = PuppetModule.with_identifiers(self.uuid).first
        fail Errors::NotFound, _("Couldn't find Puppet Module with id '%s'") % self.uuid unless puppet_module

        self.name = puppet_module.name
        self.author = puppet_module.author
      end
    end
  end
end
