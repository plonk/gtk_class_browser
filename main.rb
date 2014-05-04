# -*- coding: utf-8 -*-
require 'uri'
require 'gtk2'
require 'observer'
require_relative 'gtk_helper'
require_relative 'object_list'

require_relative 'model'

class MainWindow < Gtk::Window
  include Gtk
  include GtkHelper

  def initialize
    super

    set_size_request(640, 480)
    set_border_width(5)

    @model = Model.new
    @model.add_observer(self, :update)

    do_layout

    @class_list.treeview.signal_connect('cursor-changed') do
      @model.selected_class = @class_list.selected
    end
    @class_list.treeview.signal_connect('row-activated') do
      uri = "http://ruby-gnome2.sourceforge.jp/hiki.cgi?" +
        URI.encode_www_form([@class_list.selected.name])
      open_in_web_browser uri
    end
    @class_method_list.treeview.signal_connect('row-activated') do
    end
    @instance_method_list.treeview.signal_connect('row-activated') do
      unbound_method = @instance_method_list.selected
      uri = "http://ruby-gnome2.sourceforge.jp/hiki.cgi?" +
        URI.encode_www_form([unbound_method.owner.name])
      open_in_web_browser uri + "\##{unbound_method.name}"
    end
    @signal_list.treeview.signal_connect('row-activated') do
      uri = "http://ruby-gnome2.sourceforge.jp/hiki.cgi?" +
        URI.encode_www_form([@class_list.selected.name])
      open_in_web_browser uri + "\#Signals"
    end

    signal_connect("delete-event") do Gtk.main_quit; true end

    @model.notify
  end

  LIST_DEFINITIONS = {
    :instance_method => [ ['Name', 'Arity', 'Owner'],
                          [:name,
                           proc {|m| arity_human(m.arity)},
                           proc {|m| m.owner.to_s }] ],
    :class           => [ ['Class'],
                          [->(klass){klass.to_s.sub(/^Gtk::/,'')}] ],
    :class_method    => [ ['Name', 'Arity', 'Owner'],
                          [:name,
                           proc {|m| arity_human(m.arity)},
                           proc {|m| m.owner.to_s}] ]
  }

  def do_layout
    create(VBox, false, 5) do |vbox|
      @info_label = create(Label, xalign: 0)
      vbox.pack_start @info_label, false

      create(HPaned) do |hpaned|
        @class_list = \
        create(ObjectList, @model, *LIST_DEFINITIONS[:class]) do |class_list|
          hpaned.pack1 class_list, false, false
        end

        create(Notebook) do |notebook|
          notebook.scrollable = true

          @instance_method_list = \
          create(ObjectList, @model, *LIST_DEFINITIONS[:instance_method]) do |instance_method_list|
            notebook.append_page instance_method_list, Label.new('Instance Methods')
          end

          @class_method_list = \
          create(ObjectList, @model, *LIST_DEFINITIONS[:class_method]) do |class_method_list|
            notebook.append_page class_method_list, Label.new('Class Methods')
          end

          @signal_list = \
          create(ObjectList, @model, ['Name']) do |signal_list|
            notebook.append_page signal_list, Label.new('Signals')
          end

          hpaned.add2 notebook
        end

        hpaned.position = 200
        vbox.pack_start hpaned, true
      end

      add vbox
    end
  end

  def update
    @class_list.set @model.classes
    @instance_method_list.set @model.instance_methods
    @class_method_list.set @model.class_methods
    @info_label.text = @model.info_text
  end

  def open_in_web_browser(url_string)
    if RUBY_PLATFORM =~ /mingw/
      system "start", url_string
    else
      system "xdg-open", url_string
    end
  end

  def self.arity_human arity
    if arity < 0
      "#{(arity.abs - 1)}+"
    else
      arity.to_s
    end
  end
end

MainWindow.new.show_all
Gtk.main
