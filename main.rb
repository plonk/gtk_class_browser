# -*- coding: utf-8 -*-
require 'uri'
require 'gtk2'
require 'observer'
require_relative 'gtk_helper'
require_relative 'object_list'

class MainWindow < Gtk::Window
  include Gtk
  include GtkHelper

  def initialize
    super

    set_size_request(640, 480)
    set_border_width(5)

    do_layout

    @class_list.add_observer(self, :update)
    @instance_method_list.add_observer(self, :update)
    @signal_list.add_observer(self, :update)

    load_classes

    signal_connect("delete-event") do Gtk.main_quit; true end
  end

  LIST_DEFINITIONS = {
    :instance_method => [ ['Name', 'Arity', 'Owner'],
                          [:name,
                           ->(m){arity_human(m.arity)},
                           -> (m) { m.owner.to_s }] ],
    :class           => [ ['Class'],
                          [->(klass){klass.to_s.sub(/^Gtk::/,'')}] ],
    :class_method    => [ ['Name', 'Arity', 'Owner'],
                          [:name,
                           ->(m){arity_human(m.arity)},
                           ->(m){m.owner.to_s}] ]
  }

  def do_layout
    create(VBox, false, 5) do |vbox|
      @info_label = create(Label, xalign: 0)
      vbox.pack_start @info_label, false

      create(HPaned) do |hpaned|
        @class_list = create(ObjectList, *LIST_DEFINITIONS[:class]) do |class_list|
          hpaned.pack1 class_list, false, false
        end

        create(Notebook) do |notebook|
          notebook.scrollable = true

          @instance_method_list = create(ObjectList, *LIST_DEFINITIONS[:instance_method]) do |instance_method_list|
            notebook.append_page instance_method_list, Label.new('Instance Methods')
          end

          @class_method_list = create(ObjectList,
                                      *LIST_DEFINITIONS[:class_method]) do |class_method_list|
            notebook.append_page class_method_list, Label.new('Class Methods')
          end

          @signal_list = create(ObjectList, ['Name']) do |signal_list|
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

  def load_classes
    gtk_classes = Gtk.constants
      .map{|c| eval("Gtk::#{c}")}
      .sort_by(&:to_s)
      .select{|c| c.class==Class}
    @class_list.set gtk_classes
  end

  STOP_CLASSES = [Kernel, Object, BasicObject]

  def update event, *args
    if self.respond_to? event
      self.send(event, *args)
    end
  end

  def cursor_changed subject
    case subject
    when @class_list
      if klass = @class_list.selected
        info = klass.ancestors.take_while{|x| x != ::Object}.map(&:to_s).join(' < ')

        # instance_methods = klass.instance_methods - Object.instance_methods
        instance_methods = klass.instance_methods(true)
          .sort
          .map { |sym| klass.instance_method(sym) }
          .reject { |m| STOP_CLASSES.include? m.owner  }
        class_methods = klass.singleton_methods(true)
          .sort
          .map { |sym| klass.method(sym) }
        @instance_method_list.set instance_methods
        @class_method_list.set class_methods
        info += "\n#{instance_methods.size} methods"
        info += ", #{class_methods.size} methods"
        signals = klass.respond_to?(:signals) ? klass.signals : []
        @signal_list.set signals.sort

        info += ", #{signals.size} signals"
        @info_label.text = info
      else
        @instance_method_list.set []
        @class_method_list.set []
        @signal_list.set []
      end
    end
    nil
  end

  def item_activated subject
    case subject
    when @class_list
      uri = "http://ruby-gnome2.sourceforge.jp/hiki.cgi?" +
        URI.encode_www_form([@class_list.selected.name])
      open_in_web_browser uri
    when @instance_method_list
      unbound_method = @instance_method_list.selected
      uri = "http://ruby-gnome2.sourceforge.jp/hiki.cgi?" +
        URI.encode_www_form([unbound_method.owner.name])
      open_in_web_browser uri + "\##{unbound_method.name}"
    when @signal_list
      uri = "http://ruby-gnome2.sourceforge.jp/hiki.cgi?" +
        URI.encode_www_form([@class_list.selected.name])
      open_in_web_browser uri + "\#Signals"
    end
    nil
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
