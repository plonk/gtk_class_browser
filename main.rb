# -*- coding: utf-8 -*-
require 'uri'
require 'gtk2'
require 'observer'
require_relative 'gtk_helper'

class ObjectList < Gtk::ScrolledWindow
  include Observable
  include Gtk
  include GtkHelper

  attr_reader :treeview
  attr_reader :selected

  # 上矢印が昇順がいい。
  SORT_ASCENDING = Gtk::SORT_DESCENDING
  SORT_DESCENDING = Gtk::SORT_ASCENDING

  def initialize headers, attr_list = [:to_s]
    super()
    @objects = []
    @attr_list = attr_list.map(&:to_proc)
    self.hscrollbar_policy = POLICY_AUTOMATIC
    types = [String] * @attr_list.size
    @list_store = ListStore.new(*[Integer] + types)
    @treeview = create(TreeView, @list_store)
    types.size.times do |i|
      col = TreeViewColumn.new(headers[i], CellRendererText.new, text: i+1)
      col.resizable = true
      col.clickable = true
      col.sort_indicator = false
      col.signal_connect('clicked') do
        @treeview.columns.each {|c| if c!=col then c.sort_indicator = false end }
        if !col.sort_indicator? or col.sort_order == SORT_DESCENDING
          col.sort_indicator = true
          col.sort_order = SORT_ASCENDING
          @list_store.set_sort_column_id(i+1, Gtk::SORT_ASCENDING)
        else
          col.sort_order = SORT_DESCENDING
          @list_store.set_sort_column_id(i+1, Gtk::SORT_DESCENDING)
        end
      end
      @treeview.append_column col
    end
    @treeview.search_column = 1

    @treeview.signal_connect('cursor-changed', &method(:on_cursor_changed))
    @treeview.signal_connect('row-activated', &method(:on_row_activated))
    add @treeview
  end

  def on_row_activated _, path, column
    changed
    notify_observers :item_activated, self
  end

  def on_cursor_changed *_
    if iter = @treeview.selection.selected
      object_id = iter[0]
      obj = @objects.select { |obj| obj.object_id == object_id }.first
      @selected = obj
    else
      @selected = nil
    end

    changed
    notify_observers(:cursor_changed, self)
  end

  def set ary
    fail unless ary.is_a? Array

    @objects = ary
    @list_store.clear
    ary.each do |obj|
      iter = @list_store.append
      values = @attr_list.map { |f| f.call(obj) }
      iter[0] = obj.object_id
      values.each_with_index { |val, i|
        iter[i+1] = val
      }
    end
    @treeview.columns.each {|c| c.sort_indicator = false }
  end
end

class MainWindow < Gtk::Window
  include Gtk
  include GtkHelper

  def  initialize
    super

    set_size_request(640, 480)
    set_border_width(5)

    gtk_classes = Gtk.constants
      .map{|c| eval("Gtk::#{c}")}
      .sort_by(&:to_s)
      .select{|c| c.class==Class}

    create(VBox, false, 5) do |vbox|
      @info_label = create(Label, xalign: 0)
      vbox.pack_start @info_label, false

      create(HPaned) do |hpaned|
        @class_list = create(ObjectList,
                             ['Class'],
                             [->(klass){klass.to_s.sub(/^Gtk::/,'')}]) do |class_list|
          class_list.set gtk_classes
          hpaned.pack1 class_list, false, false
        end

        create(Notebook) do |notebook|
          notebook.scrollable = true

          @instance_method_list = create(ObjectList,
                                         ['Name', 'Arity', 'Owner'],
                                         [:name,
                                          ->(m){arity_human(m.arity)},
                                          ->(m){m.owner.to_s}]) do |instance_method_list|
            notebook.append_page instance_method_list, Label.new('Instance Methods')
          end

          @class_method_list = create(ObjectList,
                                      ['Name', 'Arity', 'Owner'],
                                      [:name,
                                       ->(m){arity_human(m.arity)},
                                       ->(m){m.owner.to_s}]) do |class_method_list|
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


    @class_list.add_observer(self, :update)
    @instance_method_list.add_observer(self, :update)
    @signal_list.add_observer(self, :update)

    signal_connect("delete-event") do Gtk.main_quit; true end
  end

  STOP_CLASSES = [Kernel, Object, BasicObject]

  def update event, subject
    case event
    when :cursor_changed
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
          @signal_list.set []
        end
      end
    when :item_activated
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

  def arity_human arity
    if arity < 0
      "#{(arity.abs - 1)}+"
    else
      arity.to_s
    end
  end
end

MainWindow.new.show_all
Gtk.main
