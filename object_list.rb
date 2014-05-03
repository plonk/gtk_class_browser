# -*- coding: utf-8 -*-
class ObjectList < Gtk::ScrolledWindow
  include Observable
  include Gtk
  include GtkHelper

  attr_reader :treeview
  attr_reader :selected

  # 上矢印が昇順がいい。
  UP_ARROW = Gtk::SORT_DESCENDING
  DOWN_ARROW = Gtk::SORT_ASCENDING

  def initialize headers, attr_list = [:to_s]
    super()

    self.hscrollbar_policy = POLICY_AUTOMATIC

    @objects = []
    @attr_list = attr_list.map(&:to_proc)
    types = [String] * @attr_list.size
    @list_store = ListStore.new(*[Integer] + types)
    @treeview = create(TreeView, @list_store)

    install_columns(headers)
    @treeview.search_column = 1

    @treeview.signal_connect('cursor-changed', &method(:on_cursor_changed))
    @treeview.signal_connect('row-activated', &method(:on_row_activated))
    add @treeview
  end

  def install_columns headers
    nfields = headers.size
    nfields.times do |i|
      create(TreeViewColumn, headers[i], CellRendererText.new, {text: i+1},
             resizable: true, clickable: true) do |col|
        col.signal_connect('clicked') do
          @treeview.columns.each do |c|
            if c!=col
              c.sort_indicator = false
            end
          end

          if !col.sort_indicator? or col.sort_order==DOWN_ARROW
            col.sort_indicator = true
            col.sort_order = UP_ARROW
            @list_store.set_sort_column_id(i+1, Gtk::SORT_ASCENDING)
          else
            col.sort_order = DOWN_ARROW
            @list_store.set_sort_column_id(i+1, Gtk::SORT_DESCENDING)
          end
        end
        @treeview.append_column col
      end
    end
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
