/* This file has been autogenerated by Ivory
 * Compiler version  0.1.0.0
 */
#ifndef __GCS_TRANSMIT_DRIVER_H__
#define __GCS_TRANSMIT_DRIVER_H__
#ifdef __cplusplus
extern "C" {
#endif
#include <ivory.h>
#include <smavlink/channel.h>
#include <smavlink/system.h>
#include "motorsoutput_type.h"
#include "param.h"
#include "position_type.h"
#include "sensors_type.h"
#include "servo_type.h"
#include "smavlink_message_attitude.h"
#include "smavlink_message_global_position_int.h"
#include "smavlink_message_gps_raw_int.h"
#include "smavlink_message_heartbeat.h"
#include "smavlink_message_param_value.h"
#include "smavlink_message_servo_output_raw.h"
#include "smavlink_message_vfr_hud.h"
#include "userinput_type.h"
void gcs_transmit_send_heartbeat(struct motorsoutput_result* n_var0,
                                 struct userinput_result* n_var1,
                                 struct smavlink_out_channel* n_var2,
                                 struct smavlink_system* n_var3);
void gcs_transmit_send_attitude(struct sensors_result* n_var0,
                                struct smavlink_out_channel* n_var1,
                                struct smavlink_system* n_var2);
void gcs_transmit_send_vfrhud(struct position_result* n_var0,
                              struct motorsoutput_result* n_var1,
                              struct sensors_result* n_var2,
                              struct smavlink_out_channel* n_var3,
                              struct smavlink_system* n_var4);
void gcs_transmit_send_servo_output(struct servo_result* n_var0,
                                    struct userinput_result* n_var1,
                                    struct smavlink_out_channel* n_var2,
                                    struct smavlink_system* n_var3);
void gcs_transmit_send_gps_raw_int(struct position_result* n_var0,
                                   struct smavlink_out_channel* n_var1,
                                   struct smavlink_system* n_var2);
void gcs_transmit_send_global_position_int(struct position_result* n_var0,
                                           struct sensors_result* n_var1,
                                           struct smavlink_out_channel* n_var2,
                                           struct smavlink_system* n_var3);
void gcs_transmit_send_param_value(struct param_info* n_var0,
                                   struct smavlink_out_channel* n_var1,
                                   struct smavlink_system* n_var2);
void gcs_transmit_send_params(struct smavlink_out_channel* n_var0,
                              struct smavlink_system* n_var1);

#ifdef __cplusplus
}
#endif
#endif /* __GCS_TRANSMIT_DRIVER_H__ */