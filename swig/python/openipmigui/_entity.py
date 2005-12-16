# _entity.py
#
# openipmi GUI handling for entities
#
# Author: MontaVista Software, Inc.
#         Corey Minyard <minyard@mvista.com>
#         source@mvista.com
#
# Copyright 2005 MontaVista Software Inc.
#
#  This program is free software; you can redistribute it and/or
#  modify it under the terms of the GNU Lesser General Public License
#  as published by the Free Software Foundation; either version 2 of
#  the License, or (at your option) any later version.
#
#
#  THIS SOFTWARE IS PROVIDED ``AS IS'' AND ANY EXPRESS OR IMPLIED
#  WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
#  MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
#  IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT,
#  INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
#  BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS
#  OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
#  ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR
#  TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE
#  USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#
#  You should have received a copy of the GNU Lesser General Public
#  License along with this program; if not, write to the Free
#  Software Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
#

import OpenIPMI
import _oi_logging
import wx
import _sensor
import _control
import _fru

class EntityOp:
    def __init__(self, e, func):
        self.e = e
        self.func = func

    def DoOp(self):
        rv = self.e.entity_id.to_entity(self)
        if (rv == 0):
            rv = self.rv
        return rv;

    def entity_cb(self, entity):
        self.rv = getattr(entity, self.func)(self.e)

class EntityFruViewer:
    def __init__(self, e):
        self.e = e
        self.e.entity_id.to_entity(self)

    def entity_cb(self, entity):
        fru = entity.get_fru()
        if (fru == None):
            return
        _fru.FruInfoDisplay(fru, str(self.e))


class ActivationTimeSetter(wx.Dialog):
    def __init__(self, e, name, func):
        wx.Dialog.__init__(self, None, -1, "Set " + name + " for " + str(e))
        self.e = e
        self.name = name
        self.func = func

        sizer = wx.BoxSizer(wx.VERTICAL)
        
        box1 = wx.BoxSizer(wx.HORIZONTAL)
        label = wx.StaticText(self, -1, "Value:")
        box1.Add(label, 0, wx.ALIGN_LEFT | wx.ALL, 5)
        self.value = wx.TextCtrl(self, -1, "")
        box1.Add(self.value, 0, wx.ALIGN_LEFT | wx.ALL, 5)
        sizer.Add(box1, 0, wx.ALIGN_LEFT | wx.ALL, 2)
        
        self.status = wx.StatusBar(self)
        sizer.Add(self.status, 0, wx.ALIGN_LEFT | wx.ALL, 2)

        box2 = wx.BoxSizer(wx.HORIZONTAL)
        cancel = wx.Button(self, -1, "Cancel")
        self.Bind(wx.EVT_BUTTON, self.cancel, cancel);
        box2.Add(cancel, 0, wx.ALIGN_LEFT | wx.ALL, 5);
        ok = wx.Button(self, -1, "Ok")
        self.Bind(wx.EVT_BUTTON, self.ok, ok);
        box2.Add(ok, 0, wx.ALIGN_LEFT | wx.ALL, 5);
        sizer.Add(box2, 0, wx.ALIGN_CENTRE | wx.ALL, 2)

        self.SetSizer(sizer)
        self.Bind(wx.EVT_CLOSE, self.OnClose)
        self.CenterOnScreen();
        self.setting = False

        self.err = 0
        rv = e.entity_id.to_entity(self)
        if (rv == 0):
            rv = self.err
        if (rv):
            _oi_logging.error("Error doing entity cb in activation time setter: "
                          + str(rv))
            self.Destroy()

    def cancel(self, event):
        self.Close()

    def ok(self, event):
        try:
            self.acttime = int(self.value.GetValue())
        except:
            return
        rv = self.s.sensor_id.to_sensor(self)
        if (rv == 0):
            rv = self.err
        if (rv != 0):
            _oi_logging.error("Error setting activation time: " + str(rv))
            self.Close()

    def OnClose(self, event):
        self.Destroy()

    def entity_cb(self, entity):
        if (self.setting):
            self.err = getattr(entity, 'set_' + self.func)(None)
        else:
            self.err = getattr(entity, 'get_' + self.func)(self)

    def entity_hot_swap_get_time_cb(self, entity, err):
        self.value.SetValue(str())
        self.Show(True)

class Entity:
    def __init__(self, d, entity):
        self.d = d
        self.ui = d.ui
        self.name = entity.get_name()
        self.entity_id = entity.get_id()
        self.entity_id_str = entity.get_entity_id_string()
        self.sensors = { }
        self.controls = { }
        entity.add_presence_handler(self)
        entity.add_hot_swap_handler(self)

        d.entities[self.name] = self

        # Find my parent and put myself in that hierarchy
        if (entity.is_child()):
            entity.iterate_parents(self)
            self.ui.add_entity(self.d, self, parent=self.parent)
            del self.parent # Don't leave circular reference
        else:
            self.ui.add_entity(self.d, self)
            self.parent_id = None
        self.hot_swap = "No"

        self.ui.append_item(self, 'Entity ID', self.entity_id_str)
        self.typeitem = self.ui.append_item(self, 'Type', None)
        self.idstringitem = self.ui.append_item(self, 'ID String', None)
        self.psatitem = self.ui.append_item(self,
                                            'Presence Sensor Always There',
                                            None)
        self.slotnumitem = self.ui.append_item(self, 'Slot Number', None)
        self.mcitem = self.ui.append_item(self, 'MC', None)
        self.hotswapitem = self.ui.append_item(self, 'Hot Swap', 'No')
        self.hot_swap = 'No'
        self.hot_swap_state = ''

        self.Changed(entity)

    def __str__(self):
        return self.name

    def HandleMenu(self, event):
        eitem = event.GetItem();
        menu = wx.Menu();
        doit = False

        if (self.is_fru):
            item = menu.Append(-1, "View FRU Data")
            self.d.ui.Bind(wx.EVT_MENU, self.ViewFruData, item)
            doit = True
            
        if (self.hot_swap == "Managed"):
            item = menu.Append(-1, "Request Activation")
            self.d.ui.Bind(wx.EVT_MENU, self.RequestActivation, item)
            item = menu.Append(-1, "Activate")
            self.d.ui.Bind(wx.EVT_MENU, self.Activate, item)
            item = menu.Append(-1, "Deactivate")
            self.d.ui.Bind(wx.EVT_MENU, self.Deactivate, item)
            if (self.supports_auto_activate):
                item = menu.Append(-1, "Set Auto-activate Time")
                self.d.ui.Bind(wx.EVT_MENU, self.SetAutoActTime, item)
                pass
            if (self.supports_auto_deactivate):
                item = menu.Append(-1, "Set Auto-deactivate Time")
                self.d.ui.Bind(wx.EVT_MENU, self.SetAutoDeactTime, item)
                pass
            doit = True
            pass

        if (doit):
            self.d.ui.PopupMenu(menu, self.d.ui.get_item_pos(eitem))
        menu.Destroy()

    def RequestActivation(self, event):
        oper = EntityOp(self, "set_activation_requested")
        rv = oper.DoOp()
        if (rv != 0):
            _oi_logging.error("entity set activation failed: " + str(rv))

    def Activate(self, event):
        oper = EntityOp(self, "activate")
        rv = oper.DoOp()
        if (rv != 0):
            _oi_logging.error("entity activation failed: " + str(rv))

    def Deactivate(self, event):
        oper = EntityOp(self, "deactivate")
        rv = oper.DoOp()
        if (rv != 0):
            _oi_logging.error("entity deactivation failed: " + str(rv))

    def SetAutoActTime(self, event):
        ActivationTimeSetter(self, "Activation Time", "auto_activate_time")
        
    def SetAutoDeactTime(self, event):
        ActivationTimeSetter(self, "Deactivation Time", "auto_deactivate_time")
        
    def ViewFruData(self, event):
        EntityFruViewer(self)

    def entity_activate_cb(self, entity, err):
        if (err != 0):
            _oi_logging.error("entity activate operation failed: " + str(err))
        
    def Changed(self, entity):
        self.is_fru = entity.is_fru()
        
        self.id_str = entity.get_id_string()
        eid = self.id_str
        if (eid == None):
            eid = self.entity_id_str
        if (eid != None):
            self.ui.set_item_text(self.treeroot, eid)

        self.entity_type = entity.get_type()
        self.slot_number = entity.get_physical_slot_num()
        if (self.slot_number < 0):
            self.slot_number = None

        self.mc_id = entity.get_mc_id()
        self.mc_name = None
        if (self.mc_id != None):
            self.mc_id.to_mc(self);

        if entity.is_hot_swappable():
            if entity.supports_managed_hot_swap():
                hot_swap = "Managed"
            else:
                hot_swap = "Simple"
        else:
            hot_swap = "No"
        if (hot_swap != self.hot_swap):
            self.hot_swap = hot_swap
            if (hot_swap != "No"):
                entity.get_hot_swap_state(self)
            else:
                self.hot_swap_state = ''

        self.supports_auto_activate = entity.supports_auto_activate_time()
        self.supports_auto_deactivate = entity.supports_auto_deactivate_time()

        # Fill in the various value in the GUI
        self.ui.set_item_text(self.typeitem, self.entity_type)
        self.ui.set_item_text(self.idstringitem, self.id_str)
        self.ui.set_item_text(self.psatitem,
                           str(entity.get_presence_sensor_always_there() != 0))
        self.ui.set_item_text(self.slotnumitem, self.id_str)
        self.ui.set_item_text(self.mcitem, self.mc_name)
        self.ui.set_item_text(self.hotswapitem,
                              self.hot_swap + ' ' + self.hot_swap_state)


    def entity_hot_swap_update_cb(self, entity, old_state, new_state, event):
        self.hot_swap_state = new_state
        self.ui.set_item_text(self.hotswapitem,
                              self.hot_swap + ' ' + self.hot_swap_state)
    
    def entity_hot_swap_cb(self, entity, err, state):
        if (err):
            _oi_logging.error("Error getting entity hot-swap state: " + str(err))
            return
        self.hot_swap_state = state
        self.ui.set_item_text(self.hotswapitem,
                              self.hot_swap + ' ' + self.hot_swap_state)
    
    def mc_cb(self, mc):
        self.mc_name = mc.get_name()
        
    def entity_iter_entities_cb(self, child, parent):
        self.parent_id = parent.get_id()
        self.parent = self.d.find_or_create_entity(parent)
        
    def remove(self):
        self.d.entities.pop(self.name)
        self.ui.remove_entity(self)

    def entity_sensor_update_cb(self, op, entity, sensor):
        if (op == "added"):
            e = _sensor.Sensor(self, sensor)
        elif (op == "removed"):
            self.sensors[sensor.get_name()].remove()

    def entity_control_update_cb(self, op, entity, control):
        if (op == "added"):
            e = _control.Control(self, control)
        elif (op == "removed"):
            self.controls[control.get_name()].remove()

    def entity_presence_cb(self, entity, present, event):
        if (present):
            self.ui.set_item_active(self.treeroot)
        else:
            self.ui.set_item_inactive(self.treeroot)