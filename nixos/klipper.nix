{ pkgs, ... }: {

environment.etc."fluidd.cfg".source = ./fluidd.cfg;

  services = {
    klipper = {
      enable = true;
      octoprintIntegration = true;
      settings = {
        "include fluidd.cfg" = {};

        filter = {};

        print_stats = {};

        pause_resume = {};

        display_status = {};

        virtual_sdcard = {
          path = "/var/lib/moonraker/gcodes";
        };

        dirzctl = {};

        hx711s = {
          sensor0_clk_pin = "PA4";
          sensor0_sdo_pin = "PC6";
        };

        prtouch = {
          sensor_x = 32;
          sensor_y = 30;
          clr_noz_start_x = 15;
          clr_noz_start_y = 25;
          clr_noz_len_y = 15;
          s_hot_min_temp = 160;
          s_hot_max_temp = 200;
          s_bed_max_temp = 60;
          show_msg = true;
          wipe_retract_distance = 2;
        };

        stepper_x = {
          step_pin = "PC2";
          dir_pin = "!PB9";
          enable_pin = "!PC3";
          microsteps = 16;
          rotation_distance = 40;
          endstop_pin = "~!PA5";
          position_endstop = -6;
          position_min = -6;
          position_max = 230;
          homing_speed = 80;
        };

        "tmc2208 stepper_x" = {
          uart_pin = "PB12";
          run_current = 0.60;
          sense_resistor = 0.150;
          interpolate = true;
        };

        stepper_y = {
          step_pin = "PB8";
          dir_pin = "PB7";
          enable_pin = "!PC3";
          microsteps = 16;
          rotation_distance = 40;
          endstop_pin = "~!PA6";
          position_endstop = -14;
          position_min = -14;
          position_max = 230;
          homing_speed = 80;
        };

        "tmc2208 stepper_y" = {
          uart_pin = "PB13";
          run_current = 0.60;
          sense_resistor = 0.150;
          interpolate = true;
        };

        stepper_z = {
          step_pin = "PB6";
          dir_pin = "!PB5";
          enable_pin = "!PC3";
          microsteps = 16;
          rotation_distance = 8;
          endstop_pin = "probe:z_virtual_endstop";
          position_min = -3;
          position_max = 250;
          homing_speed = 4;
          second_homing_speed = 1;
          homing_retract_dist = 2.0;
        };

        "tmc2208 stepper_z" = {
          uart_pin = "PB14";
          run_current = 0.8;
          sense_resistor = 0.150;
          interpolate = true;
        };

        extruder = {
          max_extrude_only_distance = 100.0;
          step_pin = "PB4";
          dir_pin = "PB3";
          enable_pin = "!PC3";
          microsteps = 16;
          rotation_distance = 7.44;
          nozzle_diameter = 0.400;
          filament_diameter = 1.750;
          heater_pin = "PA1";
          sensor_type = "EPCOS 100K B57560G104F";
          sensor_pin = "PC5";
          control = "pid";
          pid_Kp = 27.142;
          pid_Ki = 1.371;
          pid_Kd = 134.351;
          min_temp = 0;
          max_temp = 260;
        };

        heater_bed = {
          heater_pin = "PB2";
          sensor_type = "EPCOS 100K B57560G104F";
          sensor_pin = "PC4";
          control = "pid";
          pid_kp = 66.371;
          pid_ki = 0.846;
          pid_kd = 1301.702;
          min_temp = 0;
          max_temp = 100;
        };

        "heater_fan hotend_fan" = {
          pin = "PC1";
        };

        fan = {
          pin = "PA0";
        };

        mcu = {
          serial = "/dev/serial/by-id/usb-1a86_USB_Serial-if00-port0";
          restart_method = "command";
        };

        printer = {
          kinematics = "cartesian";
          max_velocity = 250;
          max_accel = 2500;
          max_z_velocity = 5;
          square_corner_velocity = 5.0;
          max_z_accel = 100;
        };

        bltouch = {
          sensor_pin = "^PC14";
          control_pin = "PC13";
          x_offset = -23.0;
          y_offset = -14.5;
          z_offset = 2.65;
          speed = 20;
          pin_move_time = 0.4;
          stow_on_each_sample = false;
          probe_with_touch_mode = true;
        };

        safe_z_home = {
          home_xy_position = "134,123";
          speed = 150;
          z_hop = 10;
          z_hop_speed = 10;
        };

        bed_mesh = {
          speed = 120;
          horizontal_move_z = 5;
          mesh_min = "30,30";
          mesh_max = "207,215.5";
          probe_count = "5,5";
          algorithm = "bicubic";
        };

        screws_tilt_adjust = {
          screw1 = "54.5,45.5";
          screw1_name = "front left screw";
          screw2 = "224.5,45.5";
          screw2_name = "front right screw";
          screw3 = "224.5,215.5";
          screw3_name = "rear right screw";
          screw4 = "54.5,215.5";
          screw4_name = "rear left screw";
          horizontal_move_z = 10.;
          speed = 50.;
          screw_thread = "CCW-M4";
        };

        e3v3se_display = {
          language = "english";
          logging = true;
        };
      };
    };
  };
}
