// Custom message for shiny

/*jshint
  jquery:true
*/
/*global Shiny */


function filter_namespace(arr, ns) {
  // keep only stuff with an id
  arr = arr.filter(t => t.id != undefined);
  // keep only stuff with matching id
  arr = arr.filter(t => t.id.indexOf('sleepPlot-') > -1);   
  return arr;
}

function filter_namespace_spans(arr, ns) {
  // keep only stuff with an id
  
  let arrLen = arr.length;
  keep = []
  
  for (let i = 0; i < arrLen; i++) {
    el = arr[i];
    children = el.children;
    
    if (children != undefined) {
      if (children[0] != undefined) {
        if(children[0].id.indexOf(ns) > -1) {
          keep.push(el);
        }
      }
    }
  }
  return keep;
}

// move badge 17 to target 1
// document.getElementById(targets[1].id).appendChild(badges[17]);

aesthetics = ["xvar", "yvar", "fill", "color", "size", "group", "facet"];
// aesthetics.findIndex(function(e) {return e == "fill";}) // returns 2

function select_target(targets, aes) {
  index = aesthetics.findIndex(function(e) {return e == aes});
  index = index + ''; // make it to a str
  return targets[index];
}

function select_badge(badges, var_name) {
  return badges.filter(b => b.children[0].attributes["data-value"].value == var_name)[0];
}


function clone_badge(badges, var_name) {
  badge = select_badge(badges, var_name);
  cln = badge.cloneNode(true);
  return cln;
}

// move badge asleep to target yvar
// cln = clone_badge("asleep");
// document.getElementById(select_target("yvar").id).appendChild(cln);

// Update the Shiny state from JS
// Shiny.setInputValue("sleepPlot-esquisse-dragvars", {"target": {"xvar": "t", "yvar": "asleep"}});
// Shiny.setInputValue("sleepPlot-esquisse-geom", "pop_etho");

$(function() {
  // enable/disable an input
  Shiny.addCustomMessageHandler("toggleInput", function(data) {
    $("#" + data.id).prop("disabled", !data.enable);
    if ($("#" + data.id).hasClass("selectpicker")) {
      $("#" + data.id).selectpicker("refresh");
    }
  });
  
  Shiny.addCustomMessageHandler("toggleDragula", function(data) {
    
    // Select all HTML elements that make a target in the dragula input
    // This may include instances from different modules
    // This may include weird elements at the end like document. They dont have id
    targets=Object.values($("div.box-dad.xyvar.dragula-target"));
    targets = filter_namespace(targets, data.namespace);
    
    // Select all badges
    badges = Object.values($("div.container-drag-source > div > div.dragula-block"));
    badges = filter_namespace_spans(badges, data.namespace);
  
    for (let key in data.mapping) {
      
      value = data.mapping[key];
      
      // cant clone if I dont know what badge it is
      // in that case I cant clone and I dont need to anyway
      if (value === null) {
        continue;
      }
      cln = clone_badge(badges, value);
      
      el = document.getElementById(select_target(targets, key).id);
      if (el.children.length > 0) {el.removeChild(el.children[0]);}
      el.appendChild(cln);
    }
    
      // move badge asleep to target yvar
      
      // cln = clone_badge("asleep");
      // document.getElementById(select_target("yvar").id).appendChild(cln);
      
      // Update the Shiny state from JS
      // Shiny.setInputValue("sleepPlot-esquisse-dragvars", {target: {xvar: "t", yvar: "asleep"}});
      // Shiny.setInputValue("sleepPlot-esquisse-geom", "pop_etho");
      
      // Call this in R to update dragula!
      // aesquisse::toggleDragula(namespace = "sleepPlot-esquisse", mapping = list("xvar" = "t", "yvar" = "asleep"), geom = "point")
      
      
  });
  
  Shiny.addCustomMessageHandler("updateShiny", function(data) {
    
    // Select all HTML elements that make a target in the dragula input
    // This may include instances from different modules
    // This may include weird elements at the end like document. They dont have id
    targets=Object.values($("div.box-dad.xyvar.dragula-target"));
    targets = filter_namespace(targets, data.namespace);
    
    // Select all badges
    badges = Object.values($("div.container-drag-source > div > div.dragula-block"));
    badges = filter_namespace_spans(badges, data.namespace);
  
    // console.log("Shiny.setInputValue");
    inputId = data.namespace+"dragvars";
    // console.log(inputId);
    Shiny.setInputValue(inputId, {"target": data.mapping});
    inputId = data.namespace+"geom";
    // console.log(inputId);
    Shiny.setInputValue(inputId, data.geom);
  })
    
    

  // hide or show an element
  Shiny.addCustomMessageHandler("toggleDisplay", function(data) {
    $("#" + data.id).css("display", data.display);
  });

  // Disable / enable a button
  Shiny.addCustomMessageHandler("togglewidget", function(data) {
    if (data.type == "disable") {
      $("#" + data.inputId).prop("disabled", true);
      $("#" + data.inputId).addClass("disabled");
    }
    if (data.type == "enable") {
      $("#" + data.inputId).prop("disabled", false);
      $("#" + data.inputId).removeClass("disabled");
    }
  });

  // Toggle button class
  Shiny.addCustomMessageHandler("toggleClass", function(data) {
    if (data.class == "success") {
      $("#" + data.id).removeClass("btn-primary");
      $("#" + data.id).addClass("btn-success");
    }
    if (data.class == "primary") {
      $("#" + data.id).removeClass("btn-success");
      $("#" + data.id).addClass("btn-primary");
    }
  });

  //$(".sw-dropdown").addClass("btn-group-esquisse");
  //$(".sw-dropdown > .btn").addClass("btn-charter");
  $("#sw-content-filterdrop").click(function(e) {
    e.stopPropagation();
  });
});

